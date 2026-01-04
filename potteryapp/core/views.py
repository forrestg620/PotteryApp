import os
from django.http import FileResponse, Http404, HttpResponse
from django.conf import settings
from django.contrib.auth import get_user_model
from rest_framework import viewsets, status
from rest_framework.decorators import action, api_view
from rest_framework.response import Response
from drf_spectacular.utils import extend_schema
import stripe
from .models import Post, SaleItem, PostMedia
from .serializers import PostSerializer, ShelfListingSerializer

User = get_user_model()

# Set Stripe API key from settings
if settings.STRIPE_SECRET_KEY:
    stripe.api_key = settings.STRIPE_SECRET_KEY
else:
    # Log a warning if Stripe key is not set (but don't fail at import time)
    import logging
    logger = logging.getLogger(__name__)
    logger.warning("STRIPE_SECRET_KEY is not set in environment variables")

class PostViewSet(viewsets.ModelViewSet):
    queryset = Post.objects.all()
    serializer_class = PostSerializer

    @action(detail=False, methods=['get'])
    def my_posts(self, request):
        """
        Get all posts created by the currently authenticated user.
        """
        if not request.user.is_authenticated:
            return Response({'error': 'Authentication required'}, status=status.HTTP_401_UNAUTHORIZED)
        
        posts = Post.objects.filter(creator=request.user).order_by('-created_at')
        serializer = self.get_serializer(posts, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def convert_to_shelf(self, request, pk=None):
        """
        Custom action to convert a Post to a SaleItem (shelf listing).
        Expects 'price' in request.data.
        Only the post owner can perform this action.
        Returns serialized SaleItem data.
        """
        try:
            post = self.get_object()
        except Post.DoesNotExist:
            return Response({'error': 'Post not found'}, status=status.HTTP_404_NOT_FOUND)

        # For development: Allow if user is authenticated and is the creator, or if no auth is required
        # In production, you should enforce authentication
        # For development: Allow unauthenticated requests
        # In production, you should enforce authentication and check ownership
        user = request.user
        if user.is_authenticated:
            # If authenticated, check if user is the creator
            if post.creator != user:
                return Response({'error': 'You do not have permission to shelf this post.'}, status=status.HTTP_403_FORBIDDEN)
        # If not authenticated, allow for development
        # TODO: In production, require authentication:
        # if not user.is_authenticated:
        #     return Response({'error': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)

        # Check if SaleItem already exists for this post
        if hasattr(post, 'saleitem'):
            return Response({'error': 'This post is already on the shelf.'}, status=status.HTTP_400_BAD_REQUEST)

        price_str = request.data.get('price')
        if not price_str:
            return Response({'error': 'Price is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            # Let the serializer or model enforce decimal precision and min value, etc.
            price = float(price_str)
        except (TypeError, ValueError):
            return Response({'error': 'Invalid price.'}, status=status.HTTP_400_BAD_REQUEST)

        saleitem = SaleItem.objects.create(
            post=post,
            price=price,
            is_sold=False
        )
        serializer = ShelfListingSerializer(saleitem)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    queryset = Post.objects.all()
    serializer_class = PostSerializer
    
    def create(self, request, *args, **kwargs):
        """
        Handle POST request to create a new post with image or video.
        Expects multipart/form-data with 'caption' and either 'image' or 'video' fields.
        """
        # Get caption from request data
        caption = request.data.get('caption', '')
        
        # Get image or video file from request
        image_file = request.FILES.get('image')
        video_file = request.FILES.get('video')
        
        if not image_file and not video_file:
            return Response(
                {'error': 'Image or video file is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Use the authenticated user as the creator
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required to create a post'}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        creator = request.user
        
        # Create the Post
        post = Post.objects.create(
            creator=creator,
            caption=caption
        )
        
        # Create the PostMedia for the image or video
        if image_file:
            PostMedia.objects.create(
                post=post,
                media_type=PostMedia.MEDIA_TYPE_IMAGE,
                file=image_file,
                order=0
            )
        elif video_file:
            post_media = PostMedia.objects.create(
                post=post,
                media_type=PostMedia.MEDIA_TYPE_VIDEO,
                file=video_file,
                order=0
            )
            # Refresh from database to get the generated thumbnail
            # The save() method generates the thumbnail, so we need to refresh
            post_media.refresh_from_db()
        
        # Refresh the post to get updated media with thumbnails
        # This ensures the media relationship includes the generated thumbnails
        post.refresh_from_db()
        
        # Force reload of media to ensure thumbnails are included
        list(post.media.all())
        
        # Return the created post
        serializer = PostSerializer(post, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    # 1. Add this decorator to tell schema.yaml what to expect
    @extend_schema(
        request=ShelfListingSerializer,  # "I expect a price"
        responses=PostSerializer         # "I will return the updated Post"
    )
    @action(detail=True, methods=['post'])
    def list_on_shelf(self, request, pk=None):
        post = self.get_object()
        
        # Validate the price input
        serializer = ShelfListingSerializer(data=request.data)
        if serializer.is_valid():
            price = serializer.validated_data['price']
            
            # Create or update the sale item
            SaleItem.objects.update_or_create(
                post=post,
                defaults={'price': price, 'is_sold': False}
            )
            
            # Return the updated post
            return Response(PostSerializer(post, context={'request': request}).data)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@extend_schema(
    request={'type': 'object', 'properties': {'post_id': {'type': 'integer'}}},
    responses={200: {'type': 'object', 'properties': {'client_secret': {'type': 'string'}}}}
)
def create_payment_intent(request):
    """
    Create a Stripe PaymentIntent for purchasing a post.
    Expects 'post_id' in request.data.
    Returns the client_secret for the payment intent.
    """
    post_id = request.data.get('post_id')
    
    if not post_id:
        return Response({'error': 'post_id is required'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        post = Post.objects.get(pk=post_id)
    except Post.DoesNotExist:
        return Response({'error': 'Post not found'}, status=status.HTTP_404_NOT_FOUND)
    
    # Get the related SaleItem
    try:
        sale_item = post.saleitem
    except SaleItem.DoesNotExist:
        return Response({'error': 'This post is not for sale'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Check if item is already sold
    if sale_item.is_sold:
        return Response({'error': 'This item is already sold'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Calculate price in cents
    price_decimal = sale_item.price
    price_cents = int(float(price_decimal) * 100)
    
    # Check if Stripe API key is configured
    if not settings.STRIPE_SECRET_KEY or not stripe.api_key:
        return Response(
            {'error': 'Stripe API key is not configured. Please set STRIPE_SECRET_KEY environment variable.'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
    
    try:
        # Ensure Stripe API key is set (in case it wasn't set at import time)
        if not stripe.api_key:
            stripe.api_key = settings.STRIPE_SECRET_KEY
        
        # Create Stripe PaymentIntent
        intent = stripe.PaymentIntent.create(
            amount=price_cents,
            currency='usd',
            metadata={'post_id': post.id}
        )
        
        return Response({'client_secret': intent.client_secret}, status=status.HTTP_200_OK)
    except stripe.error.StripeError as e:
        return Response({'error': f'Stripe error: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    except Exception as e:
        return Response({'error': f'Error creating payment intent: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
def mark_item_as_sold(request):
    """
    Mark a SaleItem as sold after successful payment.
    Expects 'post_id' in request.data.
    """
    post_id = request.data.get('post_id')
    
    if not post_id:
        return Response({'error': 'post_id is required'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        post = Post.objects.get(pk=post_id)
    except Post.DoesNotExist:
        return Response({'error': 'Post not found'}, status=status.HTTP_404_NOT_FOUND)
    
    # Get the related SaleItem
    try:
        sale_item = post.saleitem
    except SaleItem.DoesNotExist:
        return Response({'error': 'This post is not for sale'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Mark as sold
    sale_item.is_sold = True
    sale_item.save()
    
    # Return updated post data
    serializer = PostSerializer(post, context={'request': request})
    return Response(serializer.data, status=status.HTTP_200_OK)


def serve_media_with_range(request, path):
    """
    Serve media files with proper HTTP range request support for video streaming.
    This is required for AVPlayer to work correctly with video files.
    """
    file_path = os.path.join(settings.MEDIA_ROOT, path)
    
    if not os.path.exists(file_path):
        raise Http404("File not found")
    
    file_size = os.path.getsize(file_path)
    
    # Get the range header
    range_header = request.META.get('HTTP_RANGE', '').strip()
    
    if range_header:
        # Parse range header (e.g., "bytes=0-1023")
        range_match = range_header.replace('bytes=', '').split('-')
        start = int(range_match[0]) if range_match[0] else 0
        end = int(range_match[1]) if range_match[1] and range_match[1] else file_size - 1
        
        # Ensure valid range
        if start >= file_size or end >= file_size or start > end:
            return HttpResponse(status=416)  # Range Not Satisfiable
        
        content_length = end - start + 1
        
        # Open file and seek to start position
        file_handle = open(file_path, 'rb')
        file_handle.seek(start)
        
        # Create response with partial content
        response = FileResponse(
            file_handle,
            status=206,  # Partial Content
            content_type='application/octet-stream'
        )
        response['Content-Length'] = content_length
        response['Content-Range'] = f'bytes {start}-{end}/{file_size}'
        response['Accept-Ranges'] = 'bytes'
        
        return response
    else:
        # No range header, serve entire file
        file_handle = open(file_path, 'rb')
        response = FileResponse(file_handle)
        
        # Set content type based on file extension
        if path.lower().endswith('.mp4'):
            response['Content-Type'] = 'video/mp4'
        elif path.lower().endswith('.mov'):
            response['Content-Type'] = 'video/quicktime'
        elif path.lower().endswith(('.jpg', '.jpeg')):
            response['Content-Type'] = 'image/jpeg'
        elif path.lower().endswith('.png'):
            response['Content-Type'] = 'image/png'
        else:
            response['Content-Type'] = 'application/octet-stream'
        
        response['Content-Length'] = file_size
        response['Accept-Ranges'] = 'bytes'
        
        return response
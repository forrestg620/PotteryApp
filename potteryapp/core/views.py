import os
from django.http import FileResponse, Http404, HttpResponse
from django.conf import settings
from django.contrib.auth import get_user_model
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from drf_spectacular.utils import extend_schema
from .models import Post, SaleItem, PostMedia
from .serializers import PostSerializer, ShelfListingSerializer

User = get_user_model()

class PostViewSet(viewsets.ModelViewSet):
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
        
        # Get or create a default user (for now, use the first user or create one)
        # In production, you'd use request.user if authenticated
        try:
            creator = User.objects.first()
            if not creator:
                # Create a default user if none exists
                creator = User.objects.create_user(
                    username='default_user',
                    email='default@example.com',
                    password='default_password'
                )
        except Exception as e:
            return Response(
                {'error': f'Failed to get creator: {str(e)}'}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
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
            print(f"PostMedia after refresh - has thumbnail: {bool(post_media.thumbnail)}, thumbnail name: {post_media.thumbnail.name if post_media.thumbnail else 'None'}")
        
        # Refresh the post to get updated media with thumbnails
        # This ensures the media relationship includes the generated thumbnails
        post.refresh_from_db()
        
        # Force reload of media to ensure thumbnails are included
        # Get fresh media from database
        media_list = list(post.media.all())
        print(f"Post media count: {len(media_list)}")
        for media in media_list:
            print(f"Media {media.id}: type={media.media_type}, has_thumbnail={bool(media.thumbnail)}, thumbnail_name={media.thumbnail.name if media.thumbnail else 'None'}")
        
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
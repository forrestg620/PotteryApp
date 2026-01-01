import os
from django.http import FileResponse, Http404, HttpResponse
from django.conf import settings
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from drf_spectacular.utils import extend_schema
from .models import Post, SaleItem
from .serializers import PostSerializer, ShelfListingSerializer

class PostViewSet(viewsets.ModelViewSet):
    queryset = Post.objects.all()
    serializer_class = PostSerializer

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
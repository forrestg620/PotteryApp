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
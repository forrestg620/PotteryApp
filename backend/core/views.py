from django.shortcuts import render

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Post, SaleItem
from .serializers import PostSerializer, SaleItemSerializer

class PostViewSet(viewsets.ModelViewSet):
    queryset = Post.objects.all()
    serializer_class = PostSerializer

    @action(detail=True, methods=['post'])
    def list_on_shelf(self, request, pk=None):
        post = self.get_object()
        if hasattr(post, 'saleitem'):
            return Response({'detail': 'Post is already on shelf.'}, status=status.HTTP_400_BAD_REQUEST)
        price = request.data.get('price')
        if price is None:
            return Response({'detail': 'Price is required.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            price = float(price)
            if price <= 0:
                raise ValueError()
        except (ValueError, TypeError):
            return Response({'detail': 'Invalid price.'}, status=status.HTTP_400_BAD_REQUEST)
        sale_item = SaleItem.objects.create(post=post, price=price)
        return Response(SaleItemSerializer(sale_item).data, status=status.HTTP_201_CREATED)

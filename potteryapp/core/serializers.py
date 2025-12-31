from rest_framework import serializers
from .models import Post, SaleItem

class PostSerializer(serializers.ModelSerializer):
    is_for_sale = serializers.ReadOnlyField()

    class Meta:
        model = Post
        fields = ['id', 'creator', 'image', 'caption', 'created_at', 'is_for_sale']

class SaleItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = SaleItem
        fields = ['id', 'post', 'price', 'is_sold']

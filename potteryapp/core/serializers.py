from rest_framework import serializers
from .models import Post, SaleItem

class SaleItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = SaleItem
        fields = ['id', 'price', 'is_sold']

class PostSerializer(serializers.ModelSerializer):
    # Explicitly tell Django this is a Boolean, not a String
    is_for_sale = serializers.BooleanField(read_only=True)
    sale_item = SaleItemSerializer(read_only=True, source='saleitem')
    creator_username = serializers.CharField(read_only=True, source='creator.username')

    class Meta:
        model = Post
        fields = ['id', 'creator', 'creator_username', 'image', 'caption', 'created_at', 'is_for_sale', 'sale_item']

# NEW: A tiny serializer just for the "List on Shelf" action
class ShelfListingSerializer(serializers.Serializer):
    price = serializers.DecimalField(max_digits=10, decimal_places=2)
from rest_framework import serializers
from .models import Post, SaleItem, PostMedia

class SaleItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = SaleItem
        fields = ['id', 'price', 'is_sold']

class PostMediaSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    
    class Meta:
        model = PostMedia
        fields = ['id', 'file_url', 'media_type', 'order']
    
    def get_file_url(self, obj):
        request = self.context.get('request')
        if obj.file and hasattr(obj.file, 'url'):
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None

class PostSerializer(serializers.ModelSerializer):
    # Explicitly tell Django this is a Boolean, not a String
    is_for_sale = serializers.BooleanField(read_only=True)
    sale_item = SaleItemSerializer(read_only=True, source='saleitem')
    creator_username = serializers.CharField(read_only=True, source='creator.username')
    media = PostMediaSerializer(many=True, read_only=True)

    class Meta:
        model = Post
        fields = ['id', 'creator', 'creator_username', 'caption', 'created_at', 'is_for_sale', 'sale_item', 'media']

# NEW: A tiny serializer just for the "List on Shelf" action
class ShelfListingSerializer(serializers.Serializer):
    price = serializers.DecimalField(max_digits=10, decimal_places=2)
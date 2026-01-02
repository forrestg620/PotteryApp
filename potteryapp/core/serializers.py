from rest_framework import serializers
from .models import Post, SaleItem, PostMedia

class SaleItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = SaleItem
        fields = ['id', 'price', 'is_sold']

class PostMediaSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()
    
    class Meta:
        model = PostMedia
        fields = ['id', 'file_url', 'thumbnail_url', 'media_type', 'order']
    
    def get_file_url(self, obj):
        request = self.context.get('request')
        if obj.file and obj.file.name:
            # Get the URL from the file field
            try:
                # obj.file.url returns a relative URL like '/media/posts/media/file.jpg'
                file_url = obj.file.url
                
                # Build absolute URL if request is available
                if request:
                    # request.build_absolute_uri() will create full URL like 'http://127.0.0.1:8000/media/posts/media/file.jpg'
                    absolute_url = request.build_absolute_uri(file_url)
                    return absolute_url
                
                # If no request context, return relative URL (shouldn't happen in normal API usage)
                return file_url
            except (ValueError, AttributeError) as e:
                # File might not be saved or doesn't have a URL
                # This can happen if the file field is empty or not properly saved
                return None
        return None
    
    def get_thumbnail_url(self, obj):
        request = self.context.get('request')
        if obj.thumbnail and obj.thumbnail.name:
            try:
                thumbnail_url = obj.thumbnail.url
                if request:
                    absolute_url = request.build_absolute_uri(thumbnail_url)
                    return absolute_url
                return thumbnail_url
            except (ValueError, AttributeError) as e:
                return None
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
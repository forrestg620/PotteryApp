from django.contrib import admin
from django.utils.html import format_html
from .models import Post, SaleItem, PostMedia

# Inline admin for PostMedia
class PostMediaInline(admin.TabularInline):
    model = PostMedia
    extra = 1
    fields = ('file', 'media_type', 'order', 'file_url_display')
    readonly_fields = ('file_url_display',)
    # Allow file uploads
    can_delete = True
    
    def file_url_display(self, obj):
        if obj.file and obj.file.name:
            try:
                url = obj.file.url
                return format_html('<a href="{}" target="_blank">{}</a>', url, url)
            except:
                return 'N/A'
        return 'No file'
    file_url_display.short_description = 'File URL'

# Inline admin for SaleItem
class SaleItemInline(admin.StackedInline):
    model = SaleItem
    can_delete = False
    fields = ('price', 'is_sold')

@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ('id', 'creator', 'caption_preview', 'created_at', 'is_for_sale')
    list_filter = ('created_at', 'creator')
    search_fields = ('caption', 'creator__username')
    readonly_fields = ('created_at',)
    inlines = [PostMediaInline, SaleItemInline]
    
    def caption_preview(self, obj):
        if obj.caption:
            return obj.caption[:50] + '...' if len(obj.caption) > 50 else obj.caption
        return '-'
    caption_preview.short_description = 'Caption'

@admin.register(PostMedia)
class PostMediaAdmin(admin.ModelAdmin):
    list_display = ('id', 'post', 'media_type', 'order', 'file_preview', 'file_url_display', 'created_at')
    list_filter = ('media_type', 'created_at')
    search_fields = ('post__caption', 'post__id')
    readonly_fields = ('created_at', 'file_url_display')
    fields = ('post', 'file', 'media_type', 'order', 'file_url_display', 'created_at')
    
    def file_preview(self, obj):
        if obj.file:
            return obj.file.name
        return '-'
    file_preview.short_description = 'File'
    
    def file_url_display(self, obj):
        if obj.file and obj.file.name:
            try:
                url = obj.file.url
                # Try to build absolute URL
                absolute_url = url
                try:
                    from django.contrib.sites.models import Site
                    current_site = Site.objects.get_current()
                    absolute_url = f"http://{current_site.domain}{url}"
                except:
                    # If sites framework not configured, use localhost for development
                    absolute_url = f"http://127.0.0.1:8000{url}"
                
                return format_html(
                    '<a href="{}" target="_blank">{}</a><br><small>Relative: {}</small>',
                    absolute_url, absolute_url, url
                )
            except Exception as e:
                return format_html('<span style="color: red;">Error: {}</span>', str(e))
        return 'No file'
    file_url_display.short_description = 'File URL'
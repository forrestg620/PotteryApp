from django.db import models
from django.conf import settings
from django.core.files.base import ContentFile
from PIL import Image
import cv2
import numpy as np
import os
from io import BytesIO

# Create your models here.

class Post(models.Model):
    creator = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='posts')
    caption = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def is_for_sale(self):
        return hasattr(self, 'saleitem')

    def __str__(self):
        return f"Post by {self.creator} at {self.created_at}"


class PostMedia(models.Model):
    MEDIA_TYPE_IMAGE = 'image'
    MEDIA_TYPE_VIDEO = 'video'
    
    MEDIA_TYPE_CHOICES = [
        (MEDIA_TYPE_IMAGE, 'Image'),
        (MEDIA_TYPE_VIDEO, 'Video'),
    ]
    
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='media')
    media_type = models.CharField(max_length=10, choices=MEDIA_TYPE_CHOICES, default=MEDIA_TYPE_IMAGE)
    file = models.FileField(upload_to='posts/media/')
    thumbnail = models.ImageField(upload_to='posts/thumbnails/', blank=True)
    order = models.PositiveIntegerField(default=0, help_text='Order in which media appears')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order', 'created_at']
        verbose_name_plural = 'Post Media'

    def __str__(self):
        return f"{self.get_media_type_display()} for Post {self.post.id} (order: {self.order})"
    
    def save(self, *args, **kwargs):
        # Check if this is a new instance or if file was updated
        is_new = self.pk is None
        file_changed = False
        
        if not is_new:
            # Get the old instance to check if file changed
            try:
                old_instance = PostMedia.objects.get(pk=self.pk)
                file_changed = old_instance.file != self.file
            except PostMedia.DoesNotExist:
                pass
        
        # Save first to ensure file is saved to disk
        super().save(*args, **kwargs)
        
        # Generate thumbnail for videos if it doesn't exist
        if self.media_type == self.MEDIA_TYPE_VIDEO and self.file:
            # Check if thumbnail already exists
            has_thumbnail = self.thumbnail and self.thumbnail.name
            
            # Only generate if it's new or file was changed, and thumbnail doesn't exist
            if (is_new or file_changed) and not has_thumbnail:
                try:
                    # Get the video file path
                    video_path = self.file.path
                    
                    # Check if file exists
                    if os.path.exists(video_path):
                        # Open video file
                        cap = cv2.VideoCapture(video_path)
                        
                        if cap.isOpened():
                            # Read the first frame
                            ret, frame = cap.read()
                            cap.release()
                            
                            if ret and frame is not None:
                                # Convert BGR to RGB (OpenCV uses BGR, PIL uses RGB)
                                frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                                
                                # Convert numpy array to PIL Image
                                pil_image = Image.fromarray(frame_rgb)
                                
                                # Save PIL image to BytesIO buffer as JPEG
                                buffer = BytesIO()
                                pil_image.save(buffer, format='JPEG', quality=85)
                                buffer.seek(0)
                                
                                # Create ContentFile from buffer
                                thumbnail_content = ContentFile(buffer.read())
                                
                                # Generate thumbnail filename
                                video_filename = os.path.basename(self.file.name)
                                thumbnail_filename = f"thumb_{os.path.splitext(video_filename)[0]}.jpg"
                                
                                # Save thumbnail - this will update self.thumbnail
                                # Use update_fields to only update the thumbnail field and avoid the UNIQUE constraint error
                                self.thumbnail.save(thumbnail_filename, thumbnail_content, save=False)
                                
                                # Save again to persist the thumbnail, but only update the thumbnail field
                                # This prevents the UNIQUE constraint error
                                super().save(update_fields=['thumbnail'])
                except Exception as e:
                    # If thumbnail generation fails, continue without thumbnail
                    # You might want to log this error in production
                    pass

class SaleItem(models.Model):
    post = models.OneToOneField(Post, on_delete=models.CASCADE, related_name='saleitem')
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_sold = models.BooleanField(default=False)

    def __str__(self):
        return f"SaleItem for Post {self.post.id} - {'Sold' if self.is_sold else 'Available'}"


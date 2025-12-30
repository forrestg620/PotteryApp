from django.db import models
from django.conf import settings

# Create your models here.

class Post(models.Model):
    creator = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='posts')
    image = models.ImageField(upload_to='posts/images/')
    caption = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def is_for_sale(self):
        return hasattr(self, 'saleitem')

    def __str__(self):
        return f"Post by {self.creator} at {self.created_at}"

class SaleItem(models.Model):
    post = models.OneToOneField(Post, on_delete=models.CASCADE, related_name='saleitem')
    price = models.DecimalField(max_digits=10, decimal_places=2)
    is_sold = models.BooleanField(default=False)

    def __str__(self):
        return f"SaleItem for Post {self.post.id} - {'Sold' if self.is_sold else 'Available'}"


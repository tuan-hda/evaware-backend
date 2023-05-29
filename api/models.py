from django.db import models

from helpers.models import TrackingModel


# Create your models here.
class Product(TrackingModel):
    name = models.CharField(max_length=300, default="")
    desc = models.TextField(default="")
    price = models.IntegerField(default=0)
    thumbnail = models.TextField(
        default='https://img.freepik.com/free-photo/mid-century-modern-living-room-interior-design-with-monstera-tree_53876-129804.jpg')

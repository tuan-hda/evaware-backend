from django.db import models


# Create your models here.
class Product(models.Model):
    name = models.CharField(max_length=300, default="")
    desc = models.TextField(default="")
    price = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

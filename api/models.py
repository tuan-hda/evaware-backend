from django.contrib.postgres.fields import ArrayField
from django.db import models

from authentication.models import User
from helpers.models import TrackingModel, SoftDeleteModel


# Create your models here.
class Category(TrackingModel):
    name = models.CharField(max_length=300, default="")
    desc = models.TextField(default="", null=True, blank=True)
    img_url = models.TextField(
        default='https://img.freepik.com/free-photo/mid-century-modern-living-room-interior-design-with-monstera-tree_53876-129804.jpg')


class Product(TrackingModel, SoftDeleteModel):
    name = models.CharField(max_length=300, default="")
    desc = models.TextField(default="", null=True, blank=True)
    price = models.IntegerField(default=0)
    thumbnail = models.TextField(
        default='https://img.freepik.com/free-photo/mid-century-modern-living-room-interior-design-with-monstera-tree_53876-129804.jpg')
    category = models.ForeignKey(Category, on_delete=models.CASCADE, )
    reviews_count = models.IntegerField(default=0, blank=True, null=True)
    avg_rating = models.FloatField(default=0)


class Variation(TrackingModel, SoftDeleteModel):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='variations',
                                related_query_name='variation')
    inventory = models.IntegerField(default=0)
    name = models.CharField(max_length=300, default="")
    img_urls = ArrayField(models.TextField(default=''))


class Order(TrackingModel):
    phone = models.CharField(max_length=15, default='')
    full_name = models.CharField(max_length=300, default="")
    province = models.CharField(max_length=100, default='')
    province_code = models.IntegerField(default=0)
    district = models.CharField(max_length=100, default='')
    district_code = models.IntegerField(default=0)
    ward = models.CharField(max_length=100, default='')
    ward_code = models.IntegerField(default=0)
    street = models.CharField(max_length=300, default="")
    status = models.CharField(max_length=20, default='In progress')
    total = models.IntegerField(default=0)
    payment = models.TextField(default='COD')
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='orders', related_query_name='order')


class OrderDetail(TrackingModel):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='order_details')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='order_details')
    price = models.IntegerField(default=0)
    qty = models.IntegerField(default=0)
    variation = models.ForeignKey(Variation, on_delete=models.CASCADE)


class Review(TrackingModel):
    content = models.TextField(default="")
    rating = models.IntegerField(default=1)
    variation = models.ForeignKey(Variation, on_delete=models.CASCADE, related_name='reviews')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='reviews')
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reviews', related_query_name='review')

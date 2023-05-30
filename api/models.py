from django.contrib.postgres.fields import ArrayField
from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from authentication.models import User
from helpers.models import TrackingModel, SoftDeleteModel
from django.utils.translation import gettext_lazy as _


# Create your models here.
class Category(TrackingModel, SoftDeleteModel):
    name = models.CharField(max_length=300, default="")
    desc = models.TextField(default="", null=True, blank=True)
    img_url = models.TextField(
        default='https://img.freepik.com/free-photo/mid-century-modern-living-room-interior-design-with-monstera-tree_53876-129804.jpg')


class Product(TrackingModel, SoftDeleteModel):
    name = models.CharField(max_length=300, default="")
    desc = models.TextField(default="", null=True, blank=True)
    discount = models.IntegerField(default=0, validators=[MinValueValidator(0), MaxValueValidator(100)])
    price = models.IntegerField(default=0)
    thumbnail = models.TextField(
        default='https://img.freepik.com/free-photo/mid-century-modern-living-room-interior-design-with-monstera-tree_53876-129804.jpg')
    category = models.ForeignKey(Category, on_delete=models.CASCADE, )
    reviews_count = models.IntegerField(default=0, blank=True, null=True)
    avg_rating = models.FloatField(default=0)
    variations_count = models.IntegerField(default=0, blank=True, null=True)


class Variation(TrackingModel, SoftDeleteModel):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='variations',
                                related_query_name='variation')
    inventory = models.IntegerField(default=0)
    name = models.CharField(max_length=300, default="")
    img_urls = ArrayField(models.TextField(default=''))


class Voucher(TrackingModel, SoftDeleteModel):
    code = models.CharField(max_length=30, unique=True, error_messages={
        'unique': _("A voucher with that code already exists."),
    })
    discount = models.IntegerField(default=0, validators=[MinValueValidator(0), MaxValueValidator(100)])
    from_date = models.DateField()
    to_date = models.DateField()


class Order(TrackingModel):
    email = models.EmailField(blank=False)
    phone = models.CharField(max_length=15)
    full_name = models.CharField(max_length=300)
    province = models.CharField(max_length=100)
    province_code = models.IntegerField()
    district = models.CharField(max_length=100)
    district_code = models.IntegerField()
    ward = models.CharField(max_length=100)
    ward_code = models.IntegerField()
    street = models.CharField(max_length=300)
    status = models.CharField(max_length=20, default='In progress')
    total = models.IntegerField()
    payment = models.TextField(default='COD')
    shipping_date = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='orders', related_query_name='order')
    voucher = models.ForeignKey(Voucher, null=True, on_delete=models.CASCADE, related_name='orders',
                                related_query_name='order')


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


class Address(TrackingModel):
    email = models.EmailField(default='', blank=False)
    phone = models.CharField(max_length=15, default='')
    full_name = models.CharField(max_length=300, default="")
    province = models.CharField(max_length=100, default='')
    province_code = models.IntegerField(default=0)
    district = models.CharField(max_length=100, default='')
    district_code = models.IntegerField(default=0)
    ward = models.CharField(max_length=100, default='')
    ward_code = models.IntegerField(default=0)
    street = models.CharField(max_length=300, default="")
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='addresses',
                                   related_query_name='address')


class PaymentProvider(SoftDeleteModel, TrackingModel):
    img_url = models.TextField(default='')
    name = models.TextField(default='')
    method = models.CharField(max_length=50, default='')


class Payment(TrackingModel):
    provider = models.ForeignKey(PaymentProvider, on_delete=models.CASCADE, related_name='payments',
                                 related_query_name='payment')
    name = models.CharField(max_length=300, default='')
    exp = models.CharField(max_length=50, default='', blank=True, null=True)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='payments',
                                   related_query_name='payment')


class CartItem(TrackingModel):
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='cart_items',
                                   related_query_name='cart_item')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='cart_items',
                                related_query_name='cart_item')
    variation = models.ForeignKey(Variation, on_delete=models.CASCADE, related_name='cart_items',
                                  related_query_name='cart_item')
    qty = models.IntegerField(default=1)


class FavoriteItem(TrackingModel):
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='favorites',
                                   related_query_name='favorites')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='favorites')
    variation = models.ForeignKey(Variation, on_delete=models.CASCADE, related_name='favorites')

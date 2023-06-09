from django.contrib.postgres.fields import ArrayField
from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from authentication.models import User
from helpers.models import TrackingModel, SoftDeleteModel
from django.utils.translation import gettext_lazy as _


# Create your models here.
class Category(TrackingModel, SoftDeleteModel):
    """
    Đại diện cho một danh mục trong hệ thống E-commerce.

    Thuộc tính:
        name (str): Tên của danh mục.
        desc (str): Mô tả về danh mục (tùy chọn).
        img_url (str): Đường dẫn URL của hình ảnh danh mục

    Thuộc tính kế thừa:
        - Từ TrackingModel: created_at, updated_at
        - Từ SoftDeleteModel: is_deleted

    """

    name = models.CharField(max_length=300, default="")
    desc = models.TextField(default="", null=True, blank=True)
    img_url = models.TextField(default='')


class Product(TrackingModel, SoftDeleteModel):
    """
    Đại diện cho một sản phẩm trong hệ thống E-commerce.

    Thuộc tính:
        name (str): Tên của sản phẩm.
        desc (str): Mô tả về sản phẩm (tùy chọn).
        discount (int): Giảm giá của sản phẩm, đơn vị là phần trăm, phạm vi từ 0 - 100 (mặc định: 0).
        price (int): Giá của sản phẩm (mặc định: 0).
        thumbnail (str): Đường dẫn URL của hình ảnh xem trước cho sản phẩm (mặc định: '').
        category (Category): Danh mục của sản phẩm (ForeignKey tới Category).
        reviews_count (int): Số lượng đánh giá của sản phẩm (mặc định: 0).
        avg_rating (float): Điểm đánh giá trung bình của sản phẩm (mặc định: 0).
        variations_count (int): Số lượng biến thể sản phẩm (mặc định: 0).

    Thuộc tính kế thừa:
        - Từ TrackingModel: created_at, updated_at
        - Từ SoftDeleteModel: is_deleted

    """

    name = models.CharField(max_length=300, default="")
    desc = models.TextField(default="", null=True, blank=True)
    discount = models.IntegerField(default=0, validators=[MinValueValidator(0), MaxValueValidator(100)])
    price = models.IntegerField(default=0)
    thumbnail = models.TextField(default='')
    category = models.ForeignKey(Category, on_delete=models.CASCADE, )
    reviews_count = models.IntegerField(default=0)
    avg_rating = models.FloatField(default=0)
    variations_count = models.IntegerField(default=0)


class Variation(TrackingModel, SoftDeleteModel):
    """
    Đại diện cho một biến thể của sản phẩm trong hệ thống.

    Thuộc tính:
        product (Product): Sản phẩm (ForeignKey tới Product).
        inventory (int): Số lượng tồn kho của biến thể (mặc định: 0).
        name (str): Tên của biến thể (mặc định: "").
        img_urls (List[str]): Danh sách các đường dẫn URL hình ảnh của biến thể (mặc định: []).

    Thuộc tính kế thừa:
        - Từ TrackingModel: created_at, updated_at
        - Từ SoftDeleteModel: is_deleted

    """

    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='variations',
                                related_query_name='variation')
    inventory = models.IntegerField(default=0)
    name = models.CharField(max_length=300, default="")
    img_urls = ArrayField(models.TextField(default=''))


class Voucher(TrackingModel, SoftDeleteModel):
    """
    Đại diện cho một phiếu giảm giá trong hệ thống.

    Thuộc tính:
        code (str): Mã của phiếu giảm giá (độ dài tối đa: 30, độc nhất)
        discount (int): Giảm giá của sản phẩm, đơn vị là phần trăm, phạm vi từ 0 - 100 (mặc định: 0).
        from_date (date): Ngày bắt đầu.
        to_date (date): Ngày kết thúc.

    Thuộc tính Kế thừa:
        - Từ TrackingModel: created_at, updated_at
        - Từ SoftDeleteModel: is_deleted

    """

    code = models.CharField(max_length=30, unique=True, error_messages={
        'unique': _("A voucher with that code already exists."),
    })
    discount = models.IntegerField(default=0, validators=[MinValueValidator(0), MaxValueValidator(100)])
    from_date = models.DateField()
    to_date = models.DateField()


class UsedVoucher(TrackingModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='used_vouchers',
                             related_query_name='used_voucher')
    voucher = models.ForeignKey(Voucher, on_delete=models.CASCADE, related_name='used_vouchers',
                                related_query_name='used_voucher')


class Order(TrackingModel):
    """
    Đại diện cho một đơn hàng trong hệ thống.

    Thuộc tính:
        email (str): Địa chỉ email của khách hàng.
        phone (str): Số điện thoại của khách hàng (độ dài tối đa: 15).
        full_name (str): Họ tên của khách hàng (độ dài tối đa: 300).
        province (str): Tỉnh (độ dài tối đa: 100).
        province_code (int): Mã tỉnh.
        district (str): Tên huyện (độ dài tối đa: 100).
        district_code (int): Mã huyện.
        ward (str): Tên xã (độ dài tối đa: 100).
        ward_code (int): Mã xã.
        street (str): Tên đường, số nhà (độ dài tối đa: 300).
        status (str): Trạng thái của đơn hàng (độ dài tối đa: 20, mặc định: 'In progress').
        total (int): Tổng số tiền của đơn hàng.
        payment (str): Phương thức thanh toán (mặc định: 'COD').
        shipping_date (datetime): Ngày giao hàng.
        created_by (User): Người đặt (ForeignKey tới User).
        voucher (Voucher): Phiếu giảm giá áp dụng (ForeignKey tới Voucher).

    Thuộc tính Kế thừa:
        - Từ TrackingModel: created_at, updated_at

    """
    email = models.EmailField()
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
    """
    Đại diện cho chi tiết đơn hàng trong hệ thống.

    Thuộc tính:
        order (Order): Đơn hàng (ForeignKey tới Order).
        product (Product): Sản phẩm (ForeignKey tới Product).
        price (int): Giá của sản phẩm tại thời điểm đặt (mặc định: 0).
        qty (int): Số lượng sản phẩm (mặc định: 0).
        variation (Variation): Biến thể sản phẩm (ForeignKey tới Variation).

    Thuộc tính Kế thừa:
        - Từ TrackingModel: created_at, updated_at

    """

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='order_details')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='order_details')
    price = models.IntegerField(default=0)
    qty = models.IntegerField(default=0)
    variation = models.ForeignKey(Variation, on_delete=models.CASCADE)


class Review(TrackingModel):
    """
    Đại diện cho một đánh giá của sản phẩm trong hệ thống.

    Thuộc tính:
        content (str): Nội dung của đánh giá (mặc định: "").
        rating (int): Điểm, phạm vi 1 đến 5 (mặc định: 1).
        variation (Variation): Biến thể sản phẩm được đánh giá (ForeignKey tới Variation).
        product (Product): Sản phẩm được đánh giá (ForeignKey tới Product).
        created_by (User): Người đánh giá (ForeignKey tới User).

    Thuộc tính Kế thừa:
        - Từ TrackingModel: created_at, updated_at

    """
    content = models.TextField(default="")
    rating = models.IntegerField(default=1, validators=[MinValueValidator(1), MaxValueValidator(5)])
    variation = models.ForeignKey(Variation, on_delete=models.CASCADE, related_name='reviews')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='reviews')
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reviews', related_query_name='review')


class Address(TrackingModel):
    """
    Đại diện cho một địa chỉ trong hệ thống.

    Thuộc tính:
        email (str): Địa chỉ email (mặc định: '').
        phone (str): Số điện thoại (mặc định: '', độ dài tối đa: 15).
        full_name (str): Họ tên (mặc định: '', độ dài tối đa: 300).
        province (str): Tỉnh (mặc định: '', độ dài tối đa: 100).
        province_code (int): Mã tỉnh (mặc định: 0).
        district (str): Huyện (mặc định: '', độ dài tối đa: 100).
        district_code (int): Mã huyện (mặc định: 0).
        ward (str): Xã (mặc định: '', độ dài tối đa: 100).
        ward_code (int): Mã xã (mặc định: 0).
        street (str): Tên đường, số nhà (mặc định: '', độ dài tối đa: 300).
        created_by (User): Người tạo (ForeignKey tới User).

    Thuộc tính Kế thừa:
        - Từ TrackingModel: created_at, updated_at

    """
    email = models.EmailField(default='')
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
    """
    Đại diện cho nhà cung cấp phương thức thanh toán.

    Thuộc tính:
        img_url (str): URL của hình ảnh nhà cung cấp (mặc định: '').
        name (str): Tên (mặc định: '').
        method (str): Phương thức thanh toán (mặc định: '').

    Thuộc tính Kế thừa:
        - Từ TrackingModel: created_at, updated_at
        - Từ SoftDeleteModel: is_deleted

    """

    img_url = models.TextField(default='')
    name = models.TextField(default='')
    method = models.CharField(max_length=50, default='')


class Payment(TrackingModel):
    """
    Đại diện cho phương thức thanh toán trong hệ thống.

    Thuộc tính:
        provider (PaymentProvider): Nhà cung cấp (ForeignKey tới PaymentProvider).
        name (str): Tên của phương thức thanh toán (mặc định: '', độ dài tối đa: 300).
        exp (date): Thông tin về hạn sử dụng thanh toán (mặc định: None, cho phép rỗng).
        created_by (User): Người tạo thanh toán (ForeignKey tới User).

    Thuộc tính Kế thừa:
        - Từ TrackingModel: created_at, updated_at

    """
    provider = models.ForeignKey(PaymentProvider, on_delete=models.CASCADE, related_name='payments',
                                 related_query_name='payment')
    name = models.CharField(max_length=300, default='')
    exp = models.DateField(max_length=50, default=None, blank=True, null=True)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='payments',
                                   related_query_name='payment')


class CartItem(TrackingModel):
    """
    Đại diện cho một phần tử trong giỏ hàng của khách hàng.

    Thuộc tính:
        created_by (User): Người tạo (ForeignKey tới User).
        product (Product): Sản phẩm (ForeignKey tới Product).
        variation (Variation): Biến thể của sản phẩm (ForeignKey tới Variation).
        qty (int): Số lượng (mặc định: 1).

    Thuộc tính Kế thừa:
        - Từ TrackingModel: created_at, updated_at

    """
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='cart_items',
                                   related_query_name='cart_item')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='cart_items',
                                related_query_name='cart_item')
    variation = models.ForeignKey(Variation, on_delete=models.CASCADE, related_name='cart_items',
                                  related_query_name='cart_item')
    qty = models.IntegerField(default=1)


class FavoriteItem(TrackingModel):
    """
    Đại diện cho sản phẩm được khách hàng yêu thích.

    Thuộc tính:
        created_by (User): Người yêu thích (ForeignKey tới User).
        product (Product): Sản phẩm (ForeignKey tới Product).
        variation (Variation): Biến thể của sản phẩm (ForeignKey tới Variation).

    Thuộc tính Kế thừa:
        - Từ TrackingModel: created_at, updated_at

    """

    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='favorites',
                                   related_query_name='favorites')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='favorites')

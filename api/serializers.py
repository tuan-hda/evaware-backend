from django.db.models import Case, When
from rest_framework import serializers
from django.utils import timezone
from authentication.models import User
from evaware_backend.settings import AWS_STORAGE_BUCKET_NAME, AWS_DISTRIBUTION_DOMAIN
from .config import s3_client
from .models import (
    Product,
    Category,
    Variation,
    Order,
    OrderDetail,
    Review,
    Address,
    Payment,
    PaymentProvider,
    CartItem,
    FavoriteItem,
    Voucher,
    UsedVoucher,
)


class UserSerializer(serializers.ModelSerializer):
    """
    Serializer cho model User.

    Lớp kế thừa: serializers.ModelSerializer

    Meta (class): Cấu hình serializer.
        model: User
        exclude: Các trường được loại khỏi serialzer: password.

    """

    class Meta:
        model = User
        exclude = ("password",)


class UpdateProfileSerializer(serializers.ModelSerializer):
    """
    Serializer cho cập nhật thông tin khách hàng. Lớp này chỉ cho phép khách hàng cập nhật một số thông tin cá nhân cơ bản:
    dob, full_name, phone, gender, avatar

    Lớp kế thừa: serializers.ModelSerializer

    Meta:
        model: User
        exclude: Các trường được loại khỏi serialzer: password.
        read_only_fields: Các trường chỉ đọc (không cho khách hàng cập nhật): last_login, is_superuser, email, is_staff,
            is_active, date_joined, email_verified, groups, user_permissions, created_at, updated_at.

    """

    class Meta:
        model = User
        exclude = ("password",)
        read_only_fields = [
            "last_login",
            "is_superuser",
            "email",
            "is_staff",
            "is_active",
            "date_joined",
            "email_verified",
            "groups",
            "user_permissions",
            "created_at",
            "updated_at",
        ]


class UpdateUserSerializer(serializers.ModelSerializer):
    """
    Serializer cho cập nhật thông tin người dùng. Lớp này dành cho quản trị viên hệ thống. Sử dụng để cập nhật một số thông
    tin như phân quyền, email_verified, ... Người quản trị viên không được cập nhật các thông tin cơ bản của người dùng

    Lớp kế thừa: serializers.ModelSerializer

    Meta:
        model: User.
        exclude: Các trường được loại khỏi serialzer: password.
        read_only_fields: Các trường chỉ đọc: phone, email, dob, full_name, gender.

    """

    class Meta:
        model = User
        exclude = ("password",)
        read_only_fields = ["phone", "email", "dob", "full_name", "gender", "avatar"]


class CategorySerializer(serializers.ModelSerializer):
    """
    Serializer cho model Category.

    Lớp kế thừa: serializers.ModelSerializer

    Meta:
        model: Category.
        fields: Bao gồm tất cả các trường

    """

    class Meta:
        model = Category
        fields = "__all__"


class ReviewSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Review dùng trong trường hợp tạo, cập nhật và xóa (POST, PUT, PATCH, DELETE).

    Lớp kế thừa: serializers.ModelSerializer

    Meta:
        model:Review
        fields: Bao gồm tất cả các trường
        read_only_fields: Các trường chỉ đọc: created_by. Thuộc tính này được tự động thêm, user không cần xác định.

    """

    class Meta:
        model = Review
        fields = "__all__"
        read_only_fields = ["created_by"]

    def create(self, validated_data):
        """
        Ghi đè hàm create của lớp cha. Hàm này thêm thuộc tính created_by vào validated_data trước khi tạo một đối tượng
        Review mới. Cần làm việc này vì khi gửi request, token là thứ dùng để định danh người dùng. Vậy nên user được
        thêm vào dưới dạng thuộc tính của request, chứ không có sẵn trong data của request

        Input:
            validated_data (dict): Dữ liệu đã được kiểm tra từ serializer.

        Output:
            Review: Đối tượng Review vừa được tạo.

        """

        validated_data["created_by"] = self.context["request"].user
        return super(ReviewSerializer, self).create(validated_data)


class ViewReviewSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Review dùng trong trường hợp xem (GET). Lý do có thêm serializer này là có depth = 1. Nó tự động
    thực hiện join dữ liệu từ các bảng khóa ngoại.

    Lớp kế thừa: serializers.ModelSerializer

    Thuộc tính:
        created_by (UserSerializer): Serializer cho model User. Phải định nghĩa ở đây để loại bỏ trường password khỏi kết quả

    Meta:
        model: Review
        fields: bao gồm tất cả các trường.
        depth: 1 (tự động join dữ liệu từ các khóa ngoại).

    """

    created_by = UserSerializer()

    class Meta:
        model = Review
        fields = "__all__"
        depth = 1


class VariationSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Variation.

    Lớp kế thừa: serializers.ModelSerializer

    Meta:
        model:Variation.
        fields: Bao gồm tất cả các trường

    """

    class Meta:
        model = Variation
        fields = "__all__"


class ProductDetailSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Product cho trường hợp xem một sản phẩm. Lý do có thêm serializer này là nó tự động đính kèm
    toàn bộ biến thể cũng như đánh giá trong sản phẩm này.

    Lớp kế thừa: serializers.ModelSerializer

    Thuộc tính:
        variations (VariationSerializer): Serializer cho danh sách các biến thể có khóa ngoại tham chiếu tới sản phẩm này.
        reviews (ReviewSerializer): Serializer cho danh sách các đánh giá có khóa ngoại tham chiếu tới sản phẩm này.

    Meta
        model: Product
        fields: bao gồm tất cả các trường.
        depth: 1 (tự động join dữ liệu từ các khóa ngoại).

    """

    variations = VariationSerializer(many=True, read_only=True)

    class Meta:
        model = Product
        fields = "__all__"
        depth = 1

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        user = self.context["request"].user

        reviews = Review.objects.filter(product_id=representation['id']).order_by(
            Case(
                When(created_by=user, then=0),
                default=1,
            ),
            '-created_at'
        )
        representation['reviews'] = ViewReviewSerializer(reviews, many=True).data

        favorites = FavoriteItem.objects.filter(product=instance.id, created_by=user.id)
        if len(favorites) > 0:
            representation["is_favorited"] = True
        else:
            representation["is_favorited"] = False
        return representation


class CreateProductSerializer(serializers.ModelSerializer):
    """
    Serializer cho việc tạo mới, cập nhật hoặc xóa sản phẩm (POST, PUT, PATCH, DELETE).

    Lớp kế thừa: serializers.ModelSerializer

    Meta
        model: Product
        fields: bao gồm tất cả các trường.

    """

    class Meta:
        model = Product
        fields = "__all__"


class OrderDetailSerializer(serializers.ModelSerializer):
    """
    Serializer cho model OrderDetail.

    Lớp kế thừa: serializers.ModelSerializer

    Meta
        model: OrderDetail
        exclude: loại bỏ trường 'order' khỏi serializer (tránh trường hợp đệ quy khi sử dụng serializer này trong OrderSerializer).

    """

    class Meta:
        model = OrderDetail
        exclude = ("order",)


class ViewOrderDetailSerializer(serializers.ModelSerializer):
    """
    Serializer cho model OrderDetail để hiển thị chi tiết đơn hàng. Lý do có thêm serializer là nó tự động thực hiện join
    dữ liệu từ các bảng khóa ngoại.

    Lớp kế thừa: serializers.ModelSerializer

    Thuộc tính:
        variation (VariationSerializer): Serializer cho biến thể sản phẩm.
        product (CreateProductSerializer): Serializer cho sản phẩm.

    Meta
        model: OrderDetail
        fields: bao gồm tất cả các trường.

    """

    variation = VariationSerializer()
    product = CreateProductSerializer()

    class Meta:
        model = OrderDetail
        fields = "__all__"


class ViewOrderSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Order trong trường hợp xem (GET). Lý do có thêm serializer là nó tự động thực hiện join
    dữ liệu từ các bảng khóa ngoại.

    Lớp kế thừa: serializers.ModelSerializer

    Thuộc tính:
        order_details (ViewOrderDetailSerializer): Serializer cho chi tiết đơn hàng.
        created_by (UserSerializer): Serializer cho người tạo đơn hàng.

    Meta
        model: Order
        fields: bao gồm tất cả các trường.
        depth: 1 (tự động join dữ liệu từ các khóa ngoại).

    """

    order_details = ViewOrderDetailSerializer(many=True)
    created_by = UserSerializer()

    class Meta:
        model = Order
        fields = "__all__"
        depth = 1


class ViewOrderSerializerWithoutCreatedBy(serializers.ModelSerializer):
    """
    Serializer cho model Order để hiển thị đơn hàng (không bao gồm thông tin người tạo đơn hàng). Lý do là tránh trường hợp
    đệ quy khi sử dụng serializer này trong ViewUserSerializer

    Lớp kế thừa: serializers.ModelSerializer

    Thuộc tính:
        order_details (ViewOrderDetailSerializer): Serializer cho chi tiết đơn hàng.

    Meta
        model: Order
        fields: bao gồm tất cả các trường.

    """

    order_details = ViewOrderDetailSerializer(many=True)

    class Meta:
        model = Order
        fields = "__all__"


class VoucherSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Voucher.

    Lớp kế thừa: serializers.ModelSerializer

    Meta
        model: Voucher
        fields: bao gồm tất cả các trường.

    """

    class Meta:
        model = Voucher
        fields = "__all__"


class OrderSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Order.

    Lớp kế thừa: serializers.ModelSerializer

    Thuộc tính:
        order_details (OrderDetailSerializer): Serializer cho các chi tiết đơn ahfng.
        voucher (serializers.PrimaryKeyRelatedField): Liên kết khóa ngoại với model Voucher.
            - queryset: queryset của model Voucher.
            - allow_null: True (Cho phép null)
            - required: False (Không yêu cầu trường này)
        voucher_code (serializers.CharField): Trường CharField cho mã voucher.
            - max_length: 30
            - required: False (Không yêu cầu trường này)

    Meta: Cấu hình serializer.
        model: Order
        fields: bao gồm tất cả các trường.
        read_only_fields: Các trường chỉ đọc: created_by. Thuộc tính này được tự động thêm, user không cần xác định.
        depth: 1 (tự động join dữ liệu từ các khóa ngoại).

    """

    order_details = OrderDetailSerializer(many=True)
    voucher = serializers.PrimaryKeyRelatedField(
        queryset=Voucher.objects.all(), allow_null=True, required=False
    )
    voucher_code = serializers.CharField(max_length=30, required=False)

    class Meta:
        model = Order
        fields = "__all__"
        read_only_fields = ("created_by",)
        depth = 1

    def reverse_inventory(self, instance):
        """
        Khôi phục số lượng tồn của các biến thể sản phẩm trong order.

        Input:
            instance (Order): Đối tượng Order.

        Output: none

        """

        order_id = instance.id
        order_details = OrderDetail.objects.filter(order_id=order_id)
        for order_detail in order_details:
            variation = Variation.objects.get(id=order_detail.variation_id)
            variation.inventory += order_detail.qty
            variation.save()

    def check_status(self, instance, validated_data):
        """
        Kiểm tra hành động cập nhật trạng thái đơn hàng. Đảm bảo trạng thái hợp lệ và người gửi request có quyền cập nhật
        trạng thái. Đồng thời xử lý trường hợp hủy đơn hàng (khôi phục số lượng tồn kho, xóa lịch sử sử dụng voucher)

        Input:
            instance (Order): Đối tượng đơn hàng.
            validated_data (dict): Dữ liệu đơn hàng đã được xác thực.

        Output: none

        Exceptions:
            serializers.ValidationError: Nếu trạng thái đơn hàng không hợp lệ hoặc người dùng không có quyền thực hiện.

        """

        user = self.context["request"].user
        status = validated_data.get("status")
        if not status:
            return
        if status not in ["In progress", "Delivering", "Cancelled", "Success"]:
            raise serializers.ValidationError(
                "Invalid status type. Must be one of ['In progress', 'Delivering', 'Cancelled', 'Success']"
            )
        if instance.status != status and status != "Cancelled" and not user.is_staff:
            raise serializers.ValidationError(
                "You do not have permissions to perform this action."
            )

        if instance.status != status and status == "Cancelled":
            # Check voucher
            if instance.voucher:
                used_voucher = UsedVoucher.objects.filter(
                    voucher=instance.voucher, user=user
                ).first()
                if used_voucher:
                    used_voucher.delete()

            # Restore inventory
            self.reverse_inventory(instance)

    def update(self, instance, validated_data):
        """
        Ghi đè hàm update của lớp cha. Hàm này kiểm tra trạng thái đơn hàng trước khi thực hiện cập nhật.

        Input:
            instance (Order): Đối tượng đơn hàng.
            validated_data (dict): Dữ liệu đã được xác thực.

        Output:
            Order: Đối tượng đơn hàng sau khi được cập nhật.

        """
        self.check_status(instance, validated_data)
        return super().update(instance, validated_data)

    def check_voucher(self, validated_data):
        """
        Kiểm tra voucher và xác thực mã voucher. Đảm bảo voucher chưa được sử dụng, còn trong thời hạn.

        Input:
            validated_data (dict): Dữ liệu đã được xác thực.

        Output:
            Voucher: Đối tượng voucher nếu mã voucher hợp lệ, ngược lại là None.

        Ngoại lệ:
            serializers.ValidationError: Nếu mã voucher không hợp lệ, voucher đã hết hạn hoặc khách hàng đã sử dụng voucher.

        """
        voucher = validated_data.get("voucher")
        voucher_code = validated_data.get("voucher_code")
        if voucher is not None:
            if voucher.code != voucher_code:
                print(voucher.code, voucher_code)
                raise serializers.ValidationError("Voucher is invalid")

            current_time = timezone.now().date()
            if voucher.from_date > current_time or voucher.to_date < current_time:
                raise serializers.ValidationError("Voucher is expired")

            used_voucher = UsedVoucher.objects.filter(
                user=validated_data["created_by"], voucher=voucher
            ).first()
            if used_voucher:
                raise serializers.ValidationError("User already used this voucher")

            return voucher
        return None

    def create(self, validated_data):
        """
        Ghi đè hàm create của lớp cha. Hàm này thêm thuộc tính created_by vào validated_data trước khi tạo một đối tượng
        mới. Cần làm việc này vì khi gửi request, token là thứ dùng để định danh người dùng. Vậy nên user được
        thêm vào dưới dạng thuộc tính của request, chứ không có sẵn trong data của request.

        Bên cạnh đó, hàm gọi hàm để kiểm tra voucher. Sau đó thêm voucher vào danh sách đã sử dụng của khách hàng.
        Hàm cho phép tạo đơn hàng và các chi tiết đơn hàng trong cùng một request. Như vậy phía client chỉ cần cung cấp
        đầy đủ thông tin về chi tiết đơn hàng, không cần phải gọi request khác để tạo chi tiết đơn hàng.

        Input:
            validated_data (dict): Dữ liệu đã được xác thực.

        Output:
            Order: Đối tượng đơn hàng đã được tạo mới.

        """
        validated_data["created_by"] = self.context["request"].user
        voucher = self.check_voucher(validated_data)

        if voucher is not None:
            total = validated_data["total"]
            total = int(total * (1 - voucher.discount / 100.0))
            validated_data["total"] = total
            validated_data.pop("voucher_code")
            validated_data.pop("voucher")
        sub_data = validated_data.pop("order_details", [])
        order = Order.objects.create(voucher=voucher, **validated_data)
        for data in sub_data:
            OrderDetail.objects.create(order=order, **data)

        UsedVoucher.objects.create(voucher=voucher, user=validated_data["created_by"])
        return order


class ViewReviewSerializerWithoutCreatedBy(serializers.ModelSerializer):
    """
    Serializer cho model Review để hiển thị đơn hàng (không bao gồm thông tin người tạo đơn hàng). Lý do là tránh trường hợp
    đệ quy khi sử dụng serializer này trong ViewUserSerializer

    Lớp kế thừa: serializers.ModelSerializer

    Thuộc tính:
        variation (VariationSerializer): Serializer cho biến thể.
        product (CreateProductSerializer): Serializer cho sản phẩm.

    Meta: Cấu hình serializer.
        model: Review
        fields: bao gồm tất cả các trường.

    """

    variation = VariationSerializer()
    product = CreateProductSerializer()

    class Meta:
        model = Review
        fields = "__all__"


class ViewUserSerializer(serializers.ModelSerializer):
    """
    Serializer cho model User để hiển thị thông tin người dùng. Với lớp serializer này, thông tin về các đánh giá và
    đơn hàng của người dùng sẽ được tự động đính kèm. Đồng thời đảm bảo không bị đệ quy thuộc tính created_by ở bên trong
    các đánh giá và đơn hàng.

    Lớp kế thừa: serializers.ModelSerializer

    Thuộc tính:
        reviews (ViewReviewSerializerWithoutCreatedBy): Serializer cho các đánh giá của người dùng (đã loại bỏ created_by).
        orders (ViewOrderSerializerWithoutCreatedBy): Serializer cho các đơn hàng của người dùng (đã loại bỏ created_by).

    Meta: Cấu hình serializer.
        model: User
        exclude: loại bỏ trường password.

    """

    reviews = ViewReviewSerializerWithoutCreatedBy(many=True)
    orders = ViewOrderSerializerWithoutCreatedBy(many=True)

    class Meta:
        model = User
        exclude = ("password",)


class AddressSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Address.

    Meta: Cấu hình serializer.
        model: Address
        fields: bao gồm tất cả các trường.
        read_only_fields: ('created_by',). Thuộc tính này được tự động thêm, user không cần xác định.

    """

    class Meta:
        model = Address
        fields = "__all__"
        read_only_fields = ("created_by",)

    def create(self, validated_data):
        """
        Ghi đè hàm create của lớp cha. Hàm này thêm thuộc tính created_by vào validated_data trước khi tạo một đối tượng
        mới. Cần làm việc này vì khi gửi request, token là thứ dùng để định danh người dùng. Vậy nên user được
        thêm vào dưới dạng thuộc tính của request, chứ không có sẵn trong data của request.

        Input:
            validated_data (dict): Dữ liệu Payment đã được kiểm tra.

        Output:
            Payment: Đối tượng Payment đã được tạo.
        """
        validated_data["created_by"] = self.context["request"].user
        return super().create(validated_data)


class PaymentProviderSerializer(serializers.ModelSerializer):
    """
    Serializer cho model PaymentProvider

    Meta: cấu hình Serializer.
        model: PaymentProvider
        fields: bao gồm tất cả các trường.
    """

    class Meta:
        model = PaymentProvider
        fields = "__all__"


class ViewPaymentSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Payment trong trường hợp xem

    Thuộc tính:
        created_by (UserSerializer): Serializer for the related User model.

    Meta: cấu hình serializer.
        model: Payment
        exclude: Loại bỏ created_by (không cần thiết).
        depth: 1 (tự động join dữ liệu từ các khóa ngoại).

    """

    class Meta:
        model = Payment
        exclude = ("created_by",)
        depth = 1


class PaymentSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Payment.

    Meta: Cấu hình serializer.
        model: Payment
        fields: bao gồm tất cả các trường.
        read_only_fields: các trường chỉ đọc: created_by. Trường này đã được tự động thêm.

    Phương thức:
        create(validated_data):
            Tạo mới một đối tượng Payment. Hàm này thêm thuộc tính created_by vào validated_data
            trước khi tạo một đối tượng mới. Cần làm việc này vì khi gửi request, token là thứ dùng để định danh người dùng.
            Vậy nên user được thêm vào dưới dạng thuộc tính của request, chứ không có sẵn trong data của request.

            Input:
                validated_data (dict): Dữ liệu Payment đã được kiểm tra.

            Ouput:
                Payment: Đối tượng Payment đã được tạo.
    """

    class Meta:
        model = Payment
        fields = "__all__"
        read_only_fields = ("created_by",)

    def create(self, validated_data):
        validated_data["created_by"] = self.context["request"].user
        return super().create(validated_data)


class CartItemSerializer(serializers.ModelSerializer):
    """
    Serializer cho model CartItem.

    Meta (class): Cấu hình serializer.
        model: CartItem
        fields: bao gồm tất cả các trường.
        read_only_fields: các trường chỉ đọc: created_by. Trường này đã được tự động thêm.

    Phương thức:
        create(self, validated_data):
            Hàm ghi đè hàm create lớp cha. Hàm này thêm thuộc tính created_by vào validated_data trước khi tạo một đối
            tượng mới. Cần làm việc này vì khi gửi request, token là thứ dùng để định danh người dùng. Vậy nên user được
            thêm vào dưới dạng thuộc tính của request, chứ không có sẵn trong data của request.

            Input:
                validated_data (dict): Dữ liệu đã được xác thực.

            Output:
                cart_item (CartItem): Đối tượng CartItem đã được tạo.

    """

    class Meta:
        model = CartItem
        fields = "__all__"
        read_only_fields = [
            "created_by",
        ]

    def create(self, validated_data):
        validated_data["created_by"] = self.context["request"].user
        return super().create(validated_data)

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        representation["variation"] = VariationSerializer(
            Variation.objects.get(id=instance.variation.pk)
        ).data
        representation["product"] = ListProductSerializer(
            Product.objects.get(id=instance.product.pk),
            context={"request": self.context["request"]},
        ).data
        return representation


class ViewCartItemSerializer(serializers.ModelSerializer):
    """
    Serializer cho việc xem thông tin các đối tượng CartItem (GET). Lý do có thêm serializer này là có depth = 1. Nó tự động thực hiện join dữ liệu từ các bảng khóa ngoại.

    Meta:
        model: CartItem
        exclude: Loại bỏ trường created_by. Tránh trùng lặp thông tin.
        depth: 1 (tự động join dữ liệu từ các khóa ngoại).

    """

    class Meta:
        model = CartItem
        exclude = ("created_by",)
        depth = 1


class FavoriteItemSerializer(serializers.ModelSerializer):
    """
    Serializer cho đối tượng FavoriteItem.

    Meta:
        model: FavoriteItem
        fields: Bao gồm tất cả các trường
        read_only_fields: Các trường chỉ đọc: created_by. Thuộc tính này được tự động thêm, user không cần xác định.

    Phương thức:
        create(self, validated_data):
            Ghi đè phương thức create() để bao gồm trường 'created_by'. Cần làm việc này vì khi gửi request, token là thứ dùng để định danh người dùng. Vậy nên user được
            thêm vào dưới dạng thuộc tính của request, chứ không có sẵn trong data của request.

            Input:
                validated_data (dict): Dữ liệu FavoriteItem đã được xác thực.

            Output:
                FavoriteItem: Đối tượng FavoriteItem đã được tạo.
    """

    class Meta:
        model = FavoriteItem
        fields = "__all__"
        read_only_fields = [
            "created_by",
        ]

    def create(self, validated_data):
        validated_data["created_by"] = self.context["request"].user
        return super().create(validated_data)


class ViewFavoriteItemSerializer(serializers.ModelSerializer):
    """
    Serializer cho việc xem thông tin sản phẩm yêu thích. Lý do có thêm serializer này là có depth = 1. Nó tự động thực hiện join dữ liệu từ các bảng khóa ngoại.

    Meta:
        model: FavoriteItem
        exclude: Loại bỏ trường created_by. Tránh trùng lặp thông tin.
        depth: 1 (tự động join dữ liệu từ các khóa ngoại).

    """

    class Meta:
        model = FavoriteItem
        exclude = ("created_by",)
        depth = 1


class UsedVoucherSerializer(serializers.ModelSerializer):
    """
    Serializer cho model UsedVoucher.

    Meta:
        model: UsedVoucher
        fields: Bao gồm tất cả các trường

    """

    class Meta:
        model = UsedVoucher
        fields = "__all__"


class ListProductSerializer(serializers.ModelSerializer):
    """
    Serializer cho model Product trong trường hợp xem toàn bộ sản phẩm. Lý do có thêm serializer này là có depth = 1. Nó tự động
    thực hiện join dữ liệu từ các bảng khóa ngoại.

    Lớp kế thừa: serializers.ModelSerializer

    Meta:
        model: Product
        fields: bao gồm tất cả các trường.
        depth: 1 (tự động join dữ liệu từ các khóa ngoại).

    """

    is_favorited = serializers.BooleanField(read_only=True, required=False)

    class Meta:
        model = Product
        fields = "__all__"
        depth = 1

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        user = self.context["request"].user
        favorites = FavoriteItem.objects.filter(product=instance.id, created_by=user.id)
        if len(favorites) > 0:
            representation["is_favorited"] = True
        else:
            representation["is_favorited"] = False
        return representation


class FileUploadSerializer(serializers.Serializer):
    """
    Serializer cho việc tải file lên Amazon S3 Bucket. Sau đó trả về cho người dùng URL của file đó (thông qua Amazon CloudFront distribution)

    Thuộc tính:
        url (serializers.CharField): Đường dẫn URL của file (chỉ đọc). Đây là nội dung trả về của request
        file (serializers.FileField): Trường tệp tin (chỉ ghi). File cần upload, nội dung này sẽ không được trả về

    Phương thức:
        create(validated_data):
            Phương thức tạo mới tệp tin, lưu trữ tệp tin trên S3 và trả về đường dẫn URL.

            Input:
                validated_data (dict): Dữ liệu đã được xác thực (File tải lên)

            Output:
                dict: Trả về url của file

            Note:
                AWS_DISTRIBUTION_DOMAIN, AWS_STORAGE_BUCKET_NAME là các biến môi trường
    """

    url = serializers.CharField(read_only=True)
    file = serializers.FileField(write_only=True)

    def create(self, validated_data):
        file = validated_data["file"]
        time_str = (
            str(timezone.now())
            .replace("-", "")
            .replace(" ", "")
            .replace(":", "")
            .replace(".", "")
            .replace("+", "")
        )
        file_path = f"uploads/{time_str}"
        s3_client.put_object(Key=file_path, Body=file, Bucket=AWS_STORAGE_BUCKET_NAME)
        url = "https://" + AWS_DISTRIBUTION_DOMAIN + "/" + file_path

        return {"url": url}

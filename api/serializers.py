from rest_framework import serializers
from django.utils import timezone
from authentication.models import User
from evaware_backend.settings import AWS_STORAGE_BUCKET_NAME, AWS_DISTRIBUTION_DOMAIN
from .config import s3_client
from .models import Product, Category, Variation, Order, OrderDetail, Review, Address, Payment, PaymentProvider, \
    CartItem, FavoriteItem, Voucher


def custom_to_representation(representation, field_name):
    representation[field_name] = sorted(
        representation[field_name],
        key=lambda x: x['created_at'],  # Replace with the desired field for ordering
        reverse=False  # Set to True for reverse ordering
    )
    return representation


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        exclude = ('password',)


class UpdateProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        exclude = ('password',)
        read_only_fields = ['last_login', 'is_superuser', 'email', 'is_staff', 'is_active', 'date_joined',
                            'email_verified', 'groups', 'user_permissions', 'created_at', 'updated_at']


class UpdateUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        exclude = ('password',)
        read_only_fields = ['phone', 'email', 'dob', 'full_name', 'gender']


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'


class ReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = '__all__'
        read_only_fields = ['created_by']

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super(ReviewSerializer, self).create(validated_data)


class ViewReviewSerializer(serializers.ModelSerializer):
    created_by = UserSerializer()

    class Meta:
        model = Review
        fields = '__all__'
        depth = 1


class VariationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Variation
        fields = '__all__'


class ListProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = '__all__'
        depth = 1


class ProductSerializer(serializers.ModelSerializer):
    variations = VariationSerializer(many=True, read_only=True)
    reviews = ReviewSerializer(many=True, read_only=True)

    class Meta:
        model = Product
        fields = '__all__'


class ProductDetailSerializer(serializers.ModelSerializer):
    variations = VariationSerializer(many=True, read_only=True)
    reviews = ViewReviewSerializer(many=True, read_only=True)

    class Meta:
        model = Product
        fields = '__all__'
        depth = 1


class CreateProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']


class OrderDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderDetail
        exclude = ('order',)


class ViewOrderDetailSerializer(serializers.ModelSerializer):
    variation = VariationSerializer()
    product = CreateProductSerializer()

    class Meta:
        model = OrderDetail
        fields = '__all__'


class ViewOrderSerializer(serializers.ModelSerializer):
    order_details = ViewOrderDetailSerializer(many=True)
    created_by = UserSerializer()

    class Meta:
        model = Order
        fields = '__all__'
        depth = 1


class ViewOrderSerializerWithoutCreatedBy(serializers.ModelSerializer):
    order_details = ViewOrderDetailSerializer(many=True)

    class Meta:
        model = Order
        fields = '__all__'


class VoucherSerializer(serializers.ModelSerializer):
    class Meta:
        model = Voucher
        fields = '__all__'


class OrderSerializer(serializers.ModelSerializer):
    order_details = OrderDetailSerializer(many=True)
    voucher = serializers.PrimaryKeyRelatedField(queryset=Voucher.objects.all(), allow_null=True, required=False)
    voucher_code = serializers.CharField(max_length=30, required=False)
    created_by = UserSerializer()

    class Meta:
        model = Order
        fields = '__all__'
        depth = 1

    def check_status(self, instance, validated_data):
        user = self.context['request'].user
        status = validated_data.get('status')
        if not status:
            return
        if status not in ['In progress', 'Delivering', 'Cancelled', 'Success']:
            raise serializers.ValidationError(
                "Invalid status type. Must be one of ['In progress', 'Delivering', 'Cancelled', 'Success']")
        if instance.status != status and instance.status != 'Success' and status != 'Cancelled' and not user.is_staff:
            raise serializers.ValidationError('You do not have permissions to perform this action.')

    def update(self, instance, validated_data):
        self.check_status(instance, validated_data)
        return super().update(instance, validated_data)

    def check_voucher(self, validated_data):
        voucher = validated_data.get('voucher')
        voucher_code = validated_data.get('voucher_code')
        if voucher is not None:
            if voucher.code != voucher_code:
                print(voucher.code, voucher_code)
                raise serializers.ValidationError('Voucher is invalid')

            current_time = timezone.now().date()
            if voucher.from_date > current_time or voucher.to_date < current_time:
                raise serializers.ValidationError('Voucher is expired')

            return voucher
        return None

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        voucher = self.check_voucher(validated_data)
        if voucher is not None:
            total = validated_data['total']
            total = int(total * (1 - voucher.discount / 100.0))
            validated_data['total'] = total
            validated_data.pop('voucher_code')
            validated_data.pop('voucher')
        sub_data = validated_data.pop('order_details', [])
        order = Order.objects.create(voucher=voucher, **validated_data)
        for data in sub_data:
            OrderDetail.objects.create(order=order, **data)
        return order

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        return custom_to_representation(representation, 'order_details')


class ViewReviewSerializerWithoutCreatedBy(serializers.ModelSerializer):
    variation = VariationSerializer()
    product = CreateProductSerializer()

    class Meta:
        model = Review
        fields = '__all__'


class ViewUserSerializer(serializers.ModelSerializer):
    reviews = ViewReviewSerializerWithoutCreatedBy(many=True)
    orders = ViewOrderSerializerWithoutCreatedBy(many=True)

    class Meta:
        model = User
        exclude = ('password',)


class AddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = Address
        fields = '__all__'
        read_only_fields = ('created_by',)

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)


class PaymentProviderSerializer(serializers.ModelSerializer):
    class Meta:
        model = PaymentProvider
        fields = '__all__'


class ViewPaymentSerializer(serializers.ModelSerializer):
    created_by = UserSerializer()

    class Meta:
        model = Payment
        exclude = ('created_by',)
        depth = 1


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = '__all__'
        read_only_fields = ('created_by',)

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)


class CartItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = CartItem
        fields = '__all__'
        read_only_fields = ['created_by', ]

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)


class ViewCartItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = CartItem
        exclude = ('created_by',)
        depth = 1


class FavoriteItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = FavoriteItem
        fields = '__all__'
        read_only_fields = ['created_by', ]

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)


class ViewFavoriteItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = FavoriteItem
        exclude = ('created_by',)
        depth = 1


class FileUploadSerializer(serializers.Serializer):
    url = serializers.CharField(read_only=True)
    file = serializers.FileField(write_only=True)

    def create(self, validated_data):
        file = validated_data['file']
        time_str = str(timezone.now()).replace("-", "").replace(" ", "").replace(":", "").replace(".", "").replace("+",
                                                                                                                   "")
        file_path = f"uploads/{time_str}{file.name}"
        s3_client.put_object(Key=file_path, Body=file, Bucket=AWS_STORAGE_BUCKET_NAME)
        url = 'https://' + AWS_DISTRIBUTION_DOMAIN + '/' + file_path

        return {'url': url}

from rest_framework import serializers

from authentication.models import User
from .models import Product, Category, Variation, Order, OrderDetail, Review


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
    class Meta:
        model = Review
        fields = '__all__'
        depth = 1


class VariationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Variation
        fields = '__all__'


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
    class Meta:
        model = OrderDetail
        depth = 1
        exclude = ('order',)


class ViewOrderSerializer(serializers.ModelSerializer):
    order_details = ViewOrderDetailSerializer(many=True)

    class Meta:
        model = Order
        fields = '__all__'
        depth = 1


class OrderSerializer(serializers.ModelSerializer):
    order_details = OrderDetailSerializer(many=True)

    class Meta:
        model = Order
        fields = '__all__'
        depth = 1

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        sub_data = validated_data.pop('order_details', [])
        order = Order.objects.create(**validated_data)
        for data in sub_data:
            OrderDetail.objects.create(order=order, **data)
        return order

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        return custom_to_representation(representation, 'order_details')


class ViewUserSerializer(serializers.ModelSerializer):
    reviews = ViewReviewSerializer(many=True)
    orders = ViewOrderSerializer(many=True)

    class Meta:
        model = User
        exclude = ('password',)

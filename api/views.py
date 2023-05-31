from datetime import datetime, timedelta

from django.utils.timezone import make_aware
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import generics, status, filters, response, serializers
from rest_framework.exceptions import PermissionDenied
from rest_framework.generics import CreateAPIView, ListAPIView, RetrieveUpdateDestroyAPIView, RetrieveUpdateAPIView, \
    GenericAPIView, UpdateAPIView, RetrieveDestroyAPIView, DestroyAPIView, RetrieveAPIView
from rest_framework.permissions import IsAuthenticated, IsAdminUser

from authentication.models import User
from helpers.mixins import IncludeDeleteMixin
from .pagination import CustomPageNumberPagination
from .serializers import CreateProductSerializer, CategorySerializer, UserSerializer, \
    VariationSerializer, OrderSerializer, ReviewSerializer, ProductDetailSerializer, ViewOrderSerializer, \
    ViewReviewSerializer, ViewUserSerializer, UpdateProfileSerializer, UpdateUserSerializer, AddressSerializer, \
    PaymentProviderSerializer, PaymentSerializer, ViewPaymentSerializer, ViewCartItemSerializer, CartItemSerializer, \
    FavoriteItemSerializer, ViewFavoriteItemSerializer, ListProductSerializer, VoucherSerializer, FileUploadSerializer
from .models import Product, Category, Variation, Order, Review, Address, PaymentProvider, Payment, CartItem, \
    FavoriteItem, Voucher
from rest_framework.views import APIView
from rest_framework.response import Response
import pandas as pd
import numpy as np


class ProductView(IncludeDeleteMixin, ListAPIView):
    permission_classes = (IsAuthenticated,)
    serializer_class = ListProductSerializer
    pagination_class = CustomPageNumberPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]

    filterset_fields = ['id', 'name', 'desc', 'price', 'avg_rating', 'variation__name', 'reviews_count',
                        'category__name', 'category__id']
    search_fields = ['id', 'name', 'desc', 'price', 'avg_rating', 'variation__name', 'reviews_count', 'category__name']
    ordering_fields = ['id', 'name', 'desc', 'price', 'avg_rating', 'variation__name', 'reviews_count',
                       'category__name', 'category__id']


class CreateProductView(CreateAPIView):
    serializer_class = CreateProductSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)

    def perform_create(self, serializer):
        return serializer.save()


class ProductDetailAPIView(IncludeDeleteMixin, RetrieveUpdateDestroyAPIView):
    lookup_field = "id"

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        else:
            return [IsAuthenticated(), IsAdminUser()]

    def get_serializer_class(self):
        if self.request.method == 'GET':
            return ProductDetailSerializer
        else:
            return CreateProductSerializer


class CategoryView(ListAPIView):
    queryset = Category.objects.all().order_by('created_at')
    permission_classes = (IsAuthenticated,)
    serializer_class = CategorySerializer


class CreateCategoryView(CreateAPIView):
    serializer_class = CategorySerializer
    permission_classes = (IsAuthenticated, IsAdminUser)


class CategoryDetailAPIView(RetrieveUpdateDestroyAPIView):
    serializer_class = CategorySerializer
    lookup_field = "id"
    queryset = Category.objects.all()

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        else:
            return [IsAuthenticated(), IsAdminUser()]

    def perform_destroy(self, instance):
        instance.soft_delete()


class CreateVariationView(CreateAPIView):
    serializer_class = VariationSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)


class VariationDetailAPIView(RetrieveUpdateDestroyAPIView):
    serializer_class = VariationSerializer
    lookup_field = "id"
    queryset = Variation.objects.all()

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        else:
            return [IsAuthenticated(), IsAdminUser()]

    def perform_destroy(self, instance):
        instance.soft_delete()


class UserView(ListAPIView):
    permission_classes = (IsAuthenticated, IsAdminUser)
    serializer_class = UserSerializer

    def get_queryset(self):
        # Check if the request user is the owner of the product
        if not self.request.user.is_superuser:
            raise PermissionDenied("You do not have permission to access user information.")
        return User.objects.all()


class OrderView(ListAPIView):
    queryset = Order.objects.all().order_by('created_at')
    permission_classes = (IsAuthenticated, IsAdminUser)
    serializer_class = ViewOrderSerializer


class CreateOrderAPIView(CreateAPIView):
    permission_classes = (IsAuthenticated,)
    serializer_class = OrderSerializer


class OrderDetailAPIView(RetrieveUpdateAPIView):
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = Order.objects.all()

    def get_serializer_class(self):
        if self.request.method == 'GET':
            return ViewOrderSerializer
        else:
            return OrderSerializer  # Default serializer class

    def get_object(self):
        obj = super().get_object()
        if obj.created_by != self.request.user and not self.request.user.is_staff and not self.request.user.is_superuser:
            raise PermissionDenied("You do not have permission to access this order.")

        return obj


class CreateReviewAPIView(CreateAPIView):
    serializer_class = ReviewSerializer
    permission_classes = (IsAuthenticated,)


class ReviewDetailAPIView(RetrieveUpdateDestroyAPIView):
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = Order.objects.all()

    def get_serializer_class(self):
        if self.request.method == 'GET':
            return ViewReviewSerializer
        else:
            return ReviewSerializer

    def get_object(self):
        obj = super().get_object()
        if obj.created_by != self.request.user:
            raise PermissionDenied("You do not have permission to access this.")
        return obj


class UserUpdateProfileAPIView(UpdateAPIView):
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = User.objects.all()
    serializer_class = UpdateProfileSerializer

    def get_object(self):
        obj = super().get_object()
        if obj != self.request.user:
            raise PermissionDenied("You do not have permission to access this.")
        return obj


class CurrentUserAPIView(GenericAPIView):
    permission_classes = (IsAuthenticated,)

    def get(self, request):
        user = request.user
        serializer = ViewUserSerializer(user)
        return response.Response({'user': serializer.data})


class AdminUpdateUserAPIView(UpdateAPIView):
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = User.objects.all()
    serializer_class = UpdateUserSerializer

    def get_object(self):
        obj = super().get_object()
        if not self.request.user.is_superuser:
            raise PermissionDenied("You do not have permission to access this.")
        return obj


class AddressListView(ListAPIView):
    permission_classes = (IsAuthenticated,)
    serializer_class = AddressSerializer

    def get_queryset(self):
        return Address.objects.filter(created_by=self.request.user)


class CreateAddressView(CreateAPIView):
    serializer_class = AddressSerializer
    permission_classes = (IsAuthenticated,)


class AddressDetailAPIView(RetrieveUpdateDestroyAPIView):
    serializer_class = AddressSerializer
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = Address.objects.all()

    def get_object(self):
        obj = super().get_object()
        if obj.created_by != self.request.user:
            raise PermissionDenied("You do not have permission to access this.")
        return obj


class PaymentProviderListView(ListAPIView):
    permission_classes = (IsAuthenticated,)
    serializer_class = PaymentProviderSerializer
    queryset = PaymentProvider.objects.all()


class PaymentListView(ListAPIView):
    permission_classes = (IsAuthenticated,)
    serializer_class = ViewPaymentSerializer

    def get_queryset(self):
        return Payment.objects.filter(created_by=self.request.user)


class CreatePaymentView(CreateAPIView):
    serializer_class = PaymentSerializer
    permission_classes = (IsAuthenticated,)


class PaymentDetailAPIView(RetrieveUpdateDestroyAPIView):
    serializer_class = PaymentSerializer
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = Payment.objects.all()

    def get_object(self):
        obj = super().get_object()
        if obj.created_by != self.request.user:
            raise PermissionDenied("You do not have permission to access this.")
        return obj


class CartItemListView(ListAPIView):
    permission_classes = (IsAuthenticated,)
    serializer_class = ViewCartItemSerializer

    def get_queryset(self):
        return CartItem.objects.filter(created_by=self.request.user)


class AddToCartView(GenericAPIView):
    serializer_class = CartItemSerializer
    permission_classes = (IsAuthenticated,)

    def post(self, request):
        user = request.user
        request.data['qty'] = 1
        product = Product.objects.get(id=request.data['product'])
        variation = Variation.objects.get(id=request.data['variation'])
        instance = CartItem.objects.filter(created_by=user, variation=variation, product=product).first()
        # Check if cart item already exists in user's cart
        if instance is not None:
            # If true then update qty
            if variation.inventory <= instance.qty:
                instance.qty = variation.inventory
                instance.save()
                if instance.qty == 0:
                    instance.delete()
                raise serializers.ValidationError('Insufficient inventory. Update item qty')
            request.data['qty'] = instance.qty + 1
            serializer = self.serializer_class(instance, data=request.data, context={'request': request})
        else:
            # Else create new cart item
            if variation.inventory == 0:
                raise serializers.ValidationError('Insufficient inventory. Update item qty')
            serializer = self.serializer_class(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return response.Response(serializer.data, status=status.HTTP_200_OK)

        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MakeOrderFromCartView(GenericAPIView):
    serializer_class = OrderSerializer
    permission_classes = (IsAuthenticated,)

    def update_variation_qty(self, cart_items):
        for cart_item in cart_items:
            variation = cart_item.variation
            variation.inventory -= cart_item.qty
            variation.save()

    def remove_all_cart_items(self, cart_items):
        for cart_item in cart_items:
            cart_item.delete()

    def post(self, request):
        cart_items = CartItem.objects.filter(created_by=request.user)
        if len(cart_items) == 0:
            raise serializers.ValidationError('User has no items in cart!')

        request.data['order_details'] = []
        total = 0
        for cart_item in cart_items:
            total += cart_item.qty * cart_item.product.price
            if cart_item.variation.inventory < cart_item.qty:
                cart_item.qty = cart_item.variation.inventory
                cart_item.save()
                if cart_item.qty == 0:
                    cart_item.delete()
                raise serializers.ValidationError(
                    f'Insufficient inventory (stock) for variation')

            request.data['order_details'].append(
                {
                    'product': cart_item.product.id,
                    'variation': cart_item.variation.id,
                    'price': cart_item.product.price,
                    'qty': cart_item.qty
                }
            )
        request.data['total'] = total
        serializer = self.serializer_class(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            self.update_variation_qty(cart_items)
            self.remove_all_cart_items(cart_items)
            return response.Response(serializer.data, status=status.HTTP_200_OK)

        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CartItemDetailAPIView(RetrieveDestroyAPIView):
    serializer_class = ViewCartItemSerializer
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = CartItem.objects.all()

    def get_object(self):
        obj = super().get_object()
        if obj.created_by != self.request.user:
            raise PermissionDenied("You do not have permission to access this.")
        return obj


class ChangeQtyCartItemAPIView(UpdateAPIView):
    serializer_class = CartItemSerializer
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = CartItem.objects.all()

    def get_object(self):
        obj = super().get_object()
        if obj.created_by != self.request.user:
            raise PermissionDenied("You do not have permission to access this.")
        return obj

    def perform_update(self, serializer):
        instance = serializer.instance
        action = self.request.query_params.get('action')
        if action is None:
            action = 'inc'

        if action == 'inc':
            instance.qty += 1
        elif action == 'dec':
            if instance.qty <= 1:
                raise serializers.ValidationError("Quantity cannot be less than 1.")
            instance.qty -= 1
        else:
            raise serializers.ValidationError("Invalid action type.")

        if instance.variation.inventory < instance.qty:
            instance.qty = instance.variation.inventory
            instance.save()
            if instance.qty == 0:
                instance.delete()
            raise serializers.ValidationError(
                f"Insufficient inventory (stock) for variation. Auto reset qty item")

        instance.save()


class FavoriteItemListView(ListAPIView):
    permission_classes = (IsAuthenticated,)
    serializer_class = ViewFavoriteItemSerializer

    def get_queryset(self):
        return FavoriteItem.objects.filter(created_by=self.request.user)


class AddItemToFavoriteView(CreateAPIView):
    serializer_class = FavoriteItemSerializer
    permission_classes = (IsAuthenticated,)

    def post(self, request, *args, **kwargs):
        user = request.user
        product = Product.objects.get(id=request.data['product'])
        variation = Variation.objects.get(id=request.data['variation'])
        instance = FavoriteItem.objects.filter(created_by=user, variation=variation, product=product).first()
        # Check if favorite item already exists in user's favorite list
        if instance is not None:
            # If true then throw error
            raise serializers.ValidationError("Item's already in favorite items")
        else:
            # Else add to favorite list
            serializer = self.serializer_class(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return response.Response(serializer.data, status=status.HTTP_200_OK)

        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class DeleteFavoriteItemView(DestroyAPIView):
    serializer_class = FavoriteItemSerializer
    permission_classes = (IsAuthenticated,)
    queryset = FavoriteItem.objects.all()
    lookup_field = 'id'

    def get_object(self):
        obj = super().get_object()
        if obj.created_by != self.request.user:
            raise PermissionDenied("You do not have permission to access this.")
        return obj


class VoucherView(ListAPIView):
    queryset = Voucher.objects.all()
    permission_classes = (IsAuthenticated, IsAdminUser)
    serializer_class = VoucherSerializer


class CreateVoucherView(CreateAPIView):
    serializer_class = VoucherSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)


class VoucherDetailAPIView(RetrieveUpdateDestroyAPIView):
    serializer_class = VoucherSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)
    lookup_field = "id"
    queryset = Voucher.objects.all()

    def perform_destroy(self, instance):
        instance.soft_delete()


class GetVoucherFromCodeView(RetrieveAPIView):
    serializer_class = VoucherSerializer
    permission_classes = (IsAuthenticated,)

    def get_object(self):
        code = self.request.query_params.get('code')
        instance = Voucher.objects.filter(code=code).first()
        if instance is None:
            raise serializers.ValidationError(f'No voucher {code} found')
        return instance


class FileUploadView(GenericAPIView):
    def post(self, request, format=None):
        serializer = FileUploadSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            response_data = serializer.data
            return Response(response_data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class SaleStatisticsAPIView(GenericAPIView):
    serializer_class = OrderSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)

    def get_df_sum(self, queryset):
        serializer = OrderSerializer(queryset, many=True)
        df = pd.DataFrame(serializer.data)
        df['created_at'] = pd.to_datetime(df['created_at'])
        df['month'] = df['created_at'].dt.to_period('M')
        total = df['total'].sum()
        return df, total

    def analyze(self, prev_queryset, queryset):
        df, total = self.get_df_sum(queryset)
        monthly_totals = df.groupby('month')['total'].sum()
        monthly_totals.index = monthly_totals.index.astype(str)

        if len(prev_queryset) != 0:
            _, prev_total = self.get_df_sum(prev_queryset)
            growth = int(total * 100 / float(prev_total) - 100)
        else:
            growth = 0
        return {
            'total': total,
            'monthly_totals': monthly_totals.to_dict(),
            'growth': growth
        }

    def get(self, request):
        from_date = request.query_params.get('from_date')
        to_date = request.query_params.get('to_date')

        try:
            from_date = make_aware(datetime.strptime(from_date, '%Y-%m-%d'))
            to_date = make_aware(datetime.strptime(to_date, '%Y-%m-%d'))
        except ValueError:
            return Response({'error': 'Invalid date format'}, status=status.HTTP_400_BAD_REQUEST)

        if (to_date.year - from_date.year) * 12 + to_date.month - from_date.month > 6:
            raise serializers.ValidationError('Range exceeds 6 month!')
        num_dates = (to_date - from_date).days + 1
        prev_from_date = from_date - timedelta(days=num_dates)
        prev_to_date = from_date - timedelta(milliseconds=1)

        queryset = Order.objects.filter(status='Success', created_at__range=(from_date, to_date))
        prev_queryset = Order.objects.filter(status='Success',
                                             created_at__range=(prev_from_date, prev_to_date))
        result = self.analyze(prev_queryset, queryset)

        return Response(result, status=status.HTTP_200_OK)


class TopProductStatisticsAPIView(GenericAPIView):
    serializer_class = OrderSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)

    def analyze(self, queryset):
        serializer = self.serializer_class(queryset, many=True)
        pd.set_option('display.max_columns', None)
        pd.set_option('display.max_rows', None)
        df = pd.DataFrame(serializer.data)

        top_products = {}

        # Iterate over each order
        for order in df['order_details']:
            # Iterate over order details in the order
            for order_detail in order:
                product_id = order_detail['product']
                qty = order_detail['qty']
                price = order_detail['price']
                total = qty * price
                if product_id in top_products:
                    sales = top_products[product_id].get('sales')
                    revenue = top_products[product_id].get('revenue')
                    top_products[product_id] = {
                        'sales': sales + qty,
                        'revenue': revenue + total
                    }
                else:
                    top_products[product_id] = {
                        'sales': qty,
                        'revenue': + total
                    }

        top_products_df = pd.DataFrame.from_dict(top_products, orient='index')
        top_products_df = top_products_df.sort_values(by=['revenue', 'sales'], ascending=[False, False])
        return top_products_df.reset_index().rename(columns={'index': 'product'}).to_dict(orient='records')

    def get(self, request):
        range_type = request.query_params.get('range_type')
        if not range_type:
            range_type = 'monthly'
        elif range_type not in ['monthly', 'yearly', 'weekly', 'quarterly']:
            raise serializers.ValidationError('Range type is not valid')

        current_time = datetime.now()
        current_time_date = current_time.date()
        if range_type == 'monthly':
            queryset = Order.objects.filter(status='Success', created_at__month=current_time_date.month,
                                            created_at__lte=current_time)
        elif range_type == 'weekly':
            from_date = current_time_date - timedelta(days=6)
            queryset = Order.objects.filter(status='Success', created_at__gte=from_date, created_at__lte=current_time)
        elif range_type == 'yearly':
            queryset = Order.objects.filter(status='Success', created_at__year=current_time_date.year,
                                            created_at__lte=current_time)
        else:
            from_month = current_time_date.month - 2
            queryset = Order.objects.filter(status='Success', created_at__month__gte=from_month,
                                            created_at__lte=current_time)

        return response.Response(self.analyze(queryset), status=status.HTTP_200_OK)


class TopCategoriesAPIView(GenericAPIView):
    serializer_class = ViewOrderSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)

    def analyze(self, queryset):
        serializer = self.serializer_class(queryset, many=True)
        df = pd.DataFrame(serializer.data)

        new_buyers = df['created_by'].apply(lambda x: x['id']).nunique()
        total_orders = len(queryset)
        new_buyers_percent = round(new_buyers * 100.0 / total_orders)
        returning_percent = 100 - new_buyers_percent

        category = {}
        sum_qty = 0

        for order in df['order_details']:
            for order_detail in order:
                category_id = order_detail['product']['category']
                qty = order_detail['qty']
                if category_id in category:
                    category[category_id] += qty
                else:
                    category[category_id] = qty
                sum_qty += qty
        top_categories_df = pd.DataFrame.from_dict(category, orient='index', columns=['qty'])
        top_categories_df = top_categories_df.sort_values(by=['qty'], ascending=[False])
        arr = top_categories_df.reset_index().rename(columns={'index': 'category'}).to_dict(orient="records")
        for obj in arr:
            obj['percentage'] = round(obj['qty'] * 100.0 / sum_qty)
        return arr, new_buyers_percent, returning_percent

    def get(self, request):
        queryset = Order.objects.filter(status='Success')
        data, new_buyers_percent, returning_percent = self.analyze(queryset)
        return response.Response({
            'data': data,
            'new_buyers_percent': new_buyers_percent,
            'returning_percent': returning_percent
        }, status=status.HTTP_200_OK)

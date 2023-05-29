from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import generics, status, filters
from rest_framework.exceptions import PermissionDenied
from rest_framework.generics import CreateAPIView, ListAPIView, RetrieveUpdateDestroyAPIView, RetrieveUpdateAPIView, \
    GenericAPIView
from rest_framework.permissions import IsAuthenticated, IsAdminUser

from authentication.models import User
from helpers.mixins import IncludeDeleteMixin
from .pagination import CustomPageNumberPagination
from .serializers import ProductSerializer, CreateProductSerializer, CategorySerializer, UserSerializer, \
    VariationSerializer, OrderSerializer, ReviewSerializer, ProductDetailSerializer, ViewOrderSerializer, \
    ViewReviewSerializer
from .models import Product, Category, Variation, Order, Review
from rest_framework.views import APIView
from rest_framework.response import Response


class ProductView(IncludeDeleteMixin, ListAPIView):
    permission_classes = (IsAuthenticated,)
    serializer_class = ProductSerializer
    pagination_class = CustomPageNumberPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]

    filterset_fields = ['id', 'name', 'desc', 'price']
    search_fields = ['id', 'name', 'desc', 'price']
    ordering_fields = ['id', 'name', 'desc', 'price']

    # class GetProduct(APIView):


#     serializer_class = ProductSerializer
#
#     def get(self, request, product_id, format=None):
#         if product_id is not None:
#             product = Product.objects.filter(id=product_id)
#             if len(product) > 0:
#                 data = ProductSerializer(product[0]).data
#                 return Response(data, status=status.HTTP_200_OK)
#             return Response({'Product Not Found': 'Invalid Product Id'}, status=status.HTTP_404_NOT_FOUND)
#
#         return Response({'Bad Request': 'Id Parameter Not Found'}, status=status.HTTP_400_BAD_REQUEST)


class CreateProductView(CreateAPIView):
    serializer_class = CreateProductSerializer
    permission_classes = (IsAuthenticated,)

    def perform_create(self, serializer):
        return serializer.save()

    # def post(self, request, format=None):
    #     product = Product()
    #
    #     if not self.request.session.exists(self.request.session.session_key):
    #         self.request.session.create()
    #
    #     serializer = self.serializer_class(data=request.data)
    #     if serializer.is_valid():
    #         name, desc, price = serializer.data.get('name'), serializer.data.get('desc'), serializer.data.get('price')
    #         product = Product(name=name, desc=desc, price=price)
    #         product.save()
    #
    #     if product is not None:
    #         return Response(ProductSerializer(product).data, status=status.HTTP_201_CREATED)


class ProductDetailAPIView(IncludeDeleteMixin, RetrieveUpdateDestroyAPIView):
    serializer_class = ProductDetailSerializer
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"

    def perform_destroy(self, instance):
        instance.soft_delete()


class CategoryView(ListAPIView):
    queryset = Category.objects.all().order_by('created_at')
    permission_classes = (IsAuthenticated,)
    serializer_class = CategorySerializer


class CreateCategoryView(CreateAPIView):
    serializer_class = CategorySerializer
    permission_classes = (IsAuthenticated,)


class CategoryDetailAPIView(RetrieveUpdateDestroyAPIView):
    serializer_class = CategorySerializer
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = Category.objects.all()


class CreateVariationView(CreateAPIView):
    serializer_class = VariationSerializer
    permission_classes = (IsAuthenticated,)


class VariationDetailAPIView(RetrieveUpdateDestroyAPIView):
    serializer_class = VariationSerializer
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = Variation.objects.all()

    def perform_destroy(self, instance):
        instance.soft_delete()


class UserView(ListAPIView):
    queryset = User.objects.all()
    permission_classes = (IsAuthenticated, IsAdminUser)
    serializer_class = UserSerializer

    def get_object(self):
        obj = super().get_object()
        # Check if the request user is the owner of the product
        if not self.request.user.is_admin:
            raise PermissionDenied("You do not have permission to access user information.")
        return obj


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

# class UserDetailAPIView(RetrieveUpdateAPIView):
#     permission_classes = (IsAuthenticated,)
#     lookup_field = "id"
#     queryset = User.objects.all()
#
#     def get_serializer_class(self):
#         if self.request.method == 'GET':
#             return ViewOrderSerializer
#         else:
#             return OrderSerializer  # Default serializer class
#
#     def get_object(self):
#         obj = super().get_object()
#         if obj.created_by != self.request.user:
#             raise PermissionDenied("You do not have permission to access this.")
#         return obj

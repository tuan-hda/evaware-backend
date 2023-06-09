import random
import string
from datetime import datetime, timedelta

from django.db.models import Max, Min
from django.utils import timezone
from django.utils.timezone import make_aware
from django_filters.rest_framework import DjangoFilterBackend
from recombee_api_client.api_requests import SetItemValues, DeleteUser
from rest_framework import generics, status, filters, response, serializers
from rest_framework.exceptions import PermissionDenied, APIException
from rest_framework.generics import CreateAPIView, ListAPIView, RetrieveUpdateDestroyAPIView, RetrieveUpdateAPIView, \
    GenericAPIView, UpdateAPIView, RetrieveDestroyAPIView, DestroyAPIView, RetrieveAPIView
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from django.db.models import Q

from authentication.models import User
from evaware_backend.settings import recombee
from helpers.mixins import IncludeDeleteMixin, RecombeeProductMixin, RecombeeUserMixin, RecombeeNetworkError, \
    RecombeeRecommendMixin
from .pagination import CustomPageNumberPagination
from .serializers import CreateProductSerializer, CategorySerializer, UserSerializer, \
    VariationSerializer, OrderSerializer, ReviewSerializer, ProductDetailSerializer, ViewOrderSerializer, \
    ViewReviewSerializer, ViewUserSerializer, UpdateProfileSerializer, UpdateUserSerializer, AddressSerializer, \
    PaymentProviderSerializer, PaymentSerializer, ViewPaymentSerializer, ViewCartItemSerializer, CartItemSerializer, \
    FavoriteItemSerializer, ViewFavoriteItemSerializer, ListProductSerializer, VoucherSerializer, FileUploadSerializer
from .models import Product, Category, Variation, Order, Review, Address, PaymentProvider, Payment, CartItem, \
    FavoriteItem, Voucher, OrderDetail
from rest_framework.response import Response
import pandas as pd


class ProductView(IncludeDeleteMixin, ListAPIView):
    """
    API View cho việc hiển thị danh sách sản phẩm (Product).

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập
        serializer_class (ListProductSerializer): Serializer được sử dụng để chuyển đổi dữ liệu sản phẩm.
        query_model (Product): Model biến thể được sử dụng để lấy queryset.
        pagination_class (CustomPageNumberPagination): Lớp phân trang được sử dụng
        filter_backends (list): Danh sách các lớp lọc dữ liệu được áp dụng

        filterset_fields (list): Danh sách các trường dữ liệu có thể được lọc
        search_fields (list): Danh sách các trường dữ liệu có thể được tìm kiếm
        ordering_fields (list): Danh sách các trường dữ liệu có thể được sắp xếp

    Kế thừa:
        IncludeDeleteMixin: hỗ trợ truy vấn và thực hiện soft delete
        ListAPIView: API truy vấn dưới dạng danh sách

    """
    permission_classes = (IsAuthenticated,)
    serializer_class = ListProductSerializer
    query_model = Product
    pagination_class = CustomPageNumberPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]

    # filterset_fields = ['id', 'name', 'desc', 'price', 'avg_rating', 'variation__name',
    #                     'reviews_count', 'category__name', 'category__id', 'width', 'height', 'depth', 'weight',
    #                     'material']
    filterset_fields = {
        'id': ['exact'],
        'name': ['exact'], 'desc': ['exact'], 'price': ['exact', 'gte', 'lte'], 'avg_rating': ['exact'],
        'reviews_count': ['exact'], 'category__name': ['exact'], 'category__id': ['exact'],
    }

    search_fields = ['id', 'name', 'desc', 'price', 'avg_rating', 'variation__name', 'reviews_count',
                     'category__name']
    ordering_fields = ['id', 'name', 'desc', 'price', 'avg_rating', 'variation__name', 'reviews_count',
                       'category__name', 'category__id']

    def create_q(self, field_name, temp):
        field_values = self.request.query_params.get(field_name)
        if field_values:
            field_values = field_values.split('|')
            query = Q()
            for x in field_values:
                query |= Q(**{field_name: x})
            temp['query'] &= query

    def get_queryset(self):
        queryset = super().get_queryset()

        query = Q()
        temp = {
            "query": query
        }

        self.create_q('length', temp)
        self.create_q('width', temp)
        self.create_q('height', temp)
        self.create_q('weight', temp)
        self.create_q('material', temp)
        self.create_q('variation__name', temp)

        queryset = Product.undeleted_objects.filter(temp['query']).distinct('id', 'price').order_by('-id')

        return queryset


class CreateProductView(CreateAPIView, RecombeeProductMixin):
    """
    API View cho việc tạo mới sản phẩm (Product).

    Thuộc tính:
        serializer_class (CreateProductSerializer): Serializer được sử dụng để chuyển đổi dữ liệu tạo mới sản phẩm.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view

    Kế thừa:
        CreateAPIView: API tạo đối tượng

    """
    serializer_class = CreateProductSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)

        is_successful = self.set_recombee_item(serializer.instance, cascade_create=True)
        if is_successful == 1:
            return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
        else:
            serializer.instance.delete()
            return self.recombee_network_error()


class ProductDetailAPIView(IncludeDeleteMixin, RetrieveUpdateDestroyAPIView, RecombeeProductMixin, RecombeeUserMixin,
                           RecombeeRecommendMixin):
    """
    View cho việc hiển thị, cập nhật và xóa sản phẩm chi tiết (Product).

    Thuộc tính:
        lookup_field (str): Trường dùng để tìm kiếm sản phẩm
        query_model (Product): Model biến thể được sử dụng để lấy queryset.

    Methods:
        get_permissions():
            Trả về danh sách các lớp kiểm tra quyền truy cập cho view. Nếu phương thức request là GET thì chỉ cần đăng nhập, ngược lại cần phải là staff user

            Input: none

            Output:
                list: Danh sách các lớp kiểm tra quyền truy cập.


        get_serializer_class():
            Trả về lớp serializer phù hợp với phương thức request.

            Input: none

            Output:
                serializer_class: Lớp serializer phù hợp.

    Kế thừa:
        IncludeDeleteMixin: hỗ trợ truy vấn và thực hiện soft delete
        RetrieveUpdateDestroyAPIView: API truy vấn thông tin chi tiết, cập nhật và xóa
    """
    lookup_field = "id"
    query_model = Product

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

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        old_data = self.get_serializer(instance, partial=partial).data
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        if getattr(instance, '_prefetched_objects_cache', None):
            instance._prefetched_objects_cache = {}

        if self.set_recombee_item(serializer.instance) == 1:
            return Response(serializer.data)
        else:
            old_serializer = self.get_serializer(instance, data=old_data, partial=partial)
            old_serializer.is_valid()
            self.perform_update(old_serializer)
            return self.recombee_network_error()

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        is_successful = self.set_recombee_item(instance, True)
        if is_successful == 1:
            self.perform_destroy(instance)
            return Response(status=status.HTTP_204_NO_CONTENT)
        else:
            return self.recombee_network_error()

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        result = serializer.data
        recomm_id = request.query_params.get('recomm_id')
        if not request.user.is_superuser and not request.user.is_staff:
            self.view_detail(request.user, instance, recomm_id=recomm_id)
            recommend = self.recommend_items_to_item(instance, request.user, 6)
            recommend_ids = [recomm['id'] for recomm in recommend['recomms']]
            recommend_items = Product.undeleted_objects.filter(id__in=recommend_ids)
            items = ListProductSerializer(data=recommend_items, many=True, context={'request': request})
            items.is_valid()
            result['recomm_items'] = items.data
            result['recomm_id'] = recommend['recommId']

        return Response(result)


class RecommendProductsForUserAPIView(ListAPIView, RecombeeRecommendMixin):
    serializer_class = ListProductSerializer
    queryset = Product.undeleted_objects.all()

    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())

        user = self.request.user
        count = self.request.query_params.get('count')
        recommend = self.recommend_items_to_user(user, count)
        queryset = queryset.filter(id__in=[recomm['id'] for recomm in recommend['recomms']])

        serializer = self.get_serializer(queryset, many=True)
        result = {'results': serializer.data, 'recomm_id': recommend['recommId']}

        return Response(result)


class PersonalizedSearchAPIView(ListAPIView, RecombeeRecommendMixin):
    serializer_class = ListProductSerializer
    queryset = Product.undeleted_objects.all()

    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())

        user = self.request.user
        query = self.request.query_params['query']
        recommend = self.search_items(user, query, 10)
        queryset = queryset.filter(id__in=[recomm['id'] for recomm in recommend['recomms']])

        serializer = self.get_serializer(queryset, many=True)
        result = {'results': serializer.data, 'recomm_id': recommend['recommId']}

        return Response(result)


class RestoreProductAPIView(GenericAPIView, RecombeeProductMixin):
    lookup_field = 'id'

    def post(self, request, id, *args, **kwargs):
        instance = Product.objects.get(id=id)
        if self.set_recombee_item(instance) == 1:
            instance.restore()
            return Response(status=status.HTTP_200_OK)
        else:
            return self.recombee_network_error()


class DeleteRecombeeProductAPIView(GenericAPIView, RecombeeProductMixin):
    lookup_field = 'id'

    def delete(self, request, id, *args, **kwargs):
        self.delete_recombee_item(id)
        return Response(data={"message": "deleted from Recombee successfully"}, status=status.HTTP_200_OK)


class CategoryView(IncludeDeleteMixin, ListAPIView):
    """
    View cho việc hiển thị danh sách các danh mục (Category).

    Thuộc tính:
        queryset (QuerySet): QuerySet chứa danh sách các danh mục sản phẩm.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated).
        serializer_class (CategorySerializer): Serializer được sử dụng để chuyển đổi dữ liệu danh mục.
        query_model (Category): Model biến thể được sử dụng để lấy queryset.

    Kế thừa:
        IncludeDeleteMixin: hỗ trợ truy vấn và thực hiện soft delete
        ListAPIView: API truy vấn dưới dạng danh sách
    """

    query_model = Category
    queryset = Category.objects.all().order_by('created_at')
    permission_classes = (IsAuthenticated,)
    serializer_class = CategorySerializer


class CreateCategoryView(CreateAPIView):
    """
    View cho việc tạo mới danh mục (Category).

    Thuộc tính:
        serializer_class (CategorySerializer): Serializer được sử dụng để chuyển đổi dữ liệu tạo mới danh mục.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated, IsAdminUser)

    Kế thừa:
        CreateAPIView: API tạo đối tượng
    """
    serializer_class = CategorySerializer
    permission_classes = (IsAuthenticated, IsAdminUser)


class CategoryDetailAPIView(IncludeDeleteMixin, RetrieveUpdateDestroyAPIView):
    """
    View cho việc hiển thị, cập nhật và xóa chi tiết danh mục (Category).

    Attributes:
        query_model (Category): Model biến thể được sử dụng để lấy queryset.
        serializer_class (CategorySerializer): Serializer được sử dụng để chuyển đổi dữ liệu danh mục.
        lookup_field (str): Trường dùng để tìm kiếm danh mục
        queryset (QuerySet): QuerySet chứa danh sách các danh mục.

    Methods:
        get_permissions():
            Trả về danh sách các lớp kiểm tra quyền truy cập cho view. Nếu phương thức request là GET thì chỉ cần đăng nhập, ngược lại cần phải là staff user

            Input: none

            Output:
                list: Danh sách các lớp kiểm tra quyền truy cập.


    Kế thừa:
        IncludeDeleteMixin: hỗ trợ truy vấn và thực hiện soft delete
        RetrieveUpdateDestroyAPIView: API truy vấn thông tin chi tiết, cập nhật và xóa

    """

    query_model = Category
    serializer_class = CategorySerializer
    lookup_field = "id"
    queryset = Category.objects.all()

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        else:
            return [IsAuthenticated(), IsAdminUser()]


class CreateVariationView(CreateAPIView):
    """
    View cho việc tạo mới biến thể (Variation).

    Attributes:
        serializer_class (VariationSerializer): Serializer được sử dụng để chuyển đổi dữ liệu tạo mới biến thể.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated, IsAdminUser)

    Kế thừa:
        CreateAPIView: API tạo đối tượng
    """
    serializer_class = VariationSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)


class VariationDetailAPIView(IncludeDeleteMixin, RetrieveUpdateDestroyAPIView):
    """
    View cho việc hiển thị, cập nhật và xóa chi tiết biến thể (Variation).

    Thuộc tính:
        serializer_class (VariationSerializer): Serializer được sử dụng để chuyển đổi dữ liệu biến thể.
        lookup_field (str): Trường dùng để tìm kiếm biến thể
        query_model (Variation): Model biến thể được sử dụng để lấy queryset.

    Phương thức:
        get_permissions():
            Trả về danh sách các lớp kiểm tra quyền truy cập cho view. Nếu phương thức request là GET thì chỉ cần đăng nhập, ngược lại cần phải là staff user

            Input: none

            Output:
                list: Danh sách các lớp kiểm tra quyền truy cập.

    Kế thừa:
        IncludeDeleteMixin: hỗ trợ truy vấn và thực hiện soft delete
        RetrieveUpdateDestroyAPIView: API truy vấn thông tin chi tiết, cập nhật và xóa
    """
    serializer_class = VariationSerializer
    lookup_field = "id"
    query_model = Variation

    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        else:
            return [IsAuthenticated(), IsAdminUser()]


class UserView(ListAPIView):
    """
    View cho việc hiển thị danh sách người dùng (User).

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view  (IsAuthenticated, IsAdminUser)
        serializer_class (UserSerializer): Serializer được sử dụng để chuyển đổi dữ liệu người dùng.

    Kế thừa:
        ListAPIView: API truy vấn dưới dạng danh sách

    """
    permission_classes = (IsAuthenticated, IsAdminUser)
    serializer_class = UserSerializer
    queryset = User.objects.all()


class OrderView(ListAPIView):
    """
    View cho việc hiển thị danh sách đơn hàng (Order).

    Thuộc tính:
        queryset (QuerySet): QuerySet chứa danh sách các đơn hàng
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated, IsAdminUser)
        serializer_class (ViewOrderSerializer): Serializer được sử dụng để chuyển đổi dữ liệu đơn hàng.

    Kế thừa:
        ListAPIView: API truy vấn dưới dạng danh sách
    """
    queryset = Order.objects.all().order_by('-created_at')
    permission_classes = (IsAuthenticated, IsAdminUser)
    serializer_class = ViewOrderSerializer


class CreateOrderAPIView(CreateAPIView):
    """
    View cho việc tạo đơn hàng mới (Order).

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        serializer_class (OrderSerializer): Serializer được sử dụng để chuyển đổi dữ liệu đơn hàng.

    Kế thừa:
        CreateAPIView: API tạo đối tượng
    """
    permission_classes = (IsAuthenticated,)
    serializer_class = OrderSerializer


class OrderDetailAPIView(RetrieveUpdateAPIView, RecombeeUserMixin):
    """
    View cho việc hiển thị, cập nhật chi tiết đơn hàng (Order).

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (đã được xác thực).
        lookup_field (str): Trường dùng để tìm kiếm đơn hàng (mặc định là 'id').
        queryset (QuerySet): QuerySet chứa danh sách các đơn hàng.

    Phương thức:
        get_serializer_class():
            Trả về lớp serializer phù hợp với phương thức request.

            Input: none

            Output:
                serializer_class: Lớp serializer phù hợp.

        get_object():
            Trả về đối tượng đơn hàng cần hiển thị hoặc cập nhật.
            Output:
                obj: Đối tượng đơn hàng.

            Exception:
                PermissionDenied: Nếu người dùng không có quyền truy cập vào đơn hàng.

    Kế thừa:
        RetrieveUpdateDestroyAPIView: API truy vấn thông tin chi tiết, cập nhật và xóa
    """
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

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        if getattr(instance, '_prefetched_objects_cache', None):
            instance._prefetched_objects_cache = {}

        if request.data['status'] == 'Cancelled':
            print(str(instance.created_at.timestamp()))
            self.cancel_order(request.user, OrderDetail.objects.filter(order_id=instance.id),
                              instance.created_at.timestamp())

        return Response(serializer.data)


class CreateReviewAPIView(CreateAPIView, RecombeeProductMixin, RecombeeUserMixin):
    """
    View cho việc tạo đánh giá mới (Review).

    Thuộc tính:
        serializer_class (ReviewSerializer): Serializer được sử dụng để chuyển đổi dữ liệu đánh giá.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view  (IsAuthenticated,)

    Kế thừa:
        CreateAPIView: API tạo đối tượng
    """
    serializer_class = ReviewSerializer
    permission_classes = (IsAuthenticated,)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)

        review = serializer.instance
        if self.set_recombee_item(review.product, review=review.rating) == 1:
            self.add_rating(request.user, review.product, review.rating, review.created_at.timestamp())
            return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
        else:
            review.delete()
            return self.recombee_network_error()


class ReviewDetailAPIView(RetrieveUpdateDestroyAPIView, RecombeeProductMixin, RecombeeUserMixin):
    """
    View cho việc hiển thị, cập nhật, xóa chi tiết đánh giá (Review).

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        lookup_field (str): Trường dùng để tìm kiếm đánh giá
        queryset (QuerySet): QuerySet chứa danh sách các đánh giá.

    Phương thức:
        get_serializer_class():
            Trả về lớp serializer phù hợp với phương thức request.

            Input: none

            Output:
                serializer_class: Lớp serializer phù hợp.

        get_object():
            Trả về đối tượng đơn hàng cần hiển thị hoặc cập nhật.
            Output:
                obj: Đối tượng đơn hàng.

            Exception:
                PermissionDenied: Nếu người dùng không có quyền truy cập vào đơn hàng.

    Kế thừa:
        RetrieveUpdateDestroyAPIView: API truy vấn thông tin chi tiết, cập nhật và xóa
    """
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = Review.objects.all()

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

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        old_rating = instance.rating
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        if getattr(instance, '_prefetched_objects_cache', None):
            instance._prefetched_objects_cache = {}

        review = serializer.instance
        if self.set_recombee_item(review.product, review=review.rating, old_review=old_rating) == 1:
            return Response(serializer.data)
        else:
            review.rating = old_rating
            review.save()
            return self.recombee_network_error()

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        review = instance
        if self.set_recombee_item(review.product, review=-review.rating) == 1:
            self.perform_destroy(instance)
            self.delete_rating(request.user, review.product, review.created_at.timestamp())
            return Response(status=status.HTTP_204_NO_CONTENT)
        else:
            return self.recombee_network_error()


class UserUpdateProfileAPIView(UpdateAPIView, RecombeeUserMixin):
    """
    View cho việc cập nhật thông tin hồ sơ người dùng.

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        lookup_field (str): Trường dùng để tìm kiếm người dùng
        queryset (QuerySet): QuerySet chứa danh sách người dùng.
        serializer_class (UpdateProfileSerializer): Serializer được sử dụng để chuyển đổi dữ liệu cập nhật hồ sơ người dùng.

    Phương thức:
        get_object():
            Trả về đối tượng người dùng cần hiển thị hoặc cập nhật.
            Output:
                obj: Đối tượng người dùng.

            Exception:
                PermissionDenied: Nếu người dùng không có quyền truy cập vào người dùng.

    Kế thừa:
        UpdateAPIView: API cập đối tượng

    """
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = User.objects.all()
    serializer_class = UpdateProfileSerializer

    def get_object(self):
        obj = super().get_object()
        if obj != self.request.user:
            raise PermissionDenied("You do not have permission to access this.")

        return obj

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        old_data = self.get_serializer(instance, partial=partial).data
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        if getattr(instance, '_prefetched_objects_cache', None):
            instance._prefetched_objects_cache = {}

        if self.set_recombee_user(instance) == 1:
            return Response(serializer.data)
        else:
            old_serializer = self.get_serializer(instance, data=old_data, partial=partial)
            self.perform_update(old_serializer)
            return RecombeeNetworkError.recombee_network_error()


class DeleteRecombeeUserAPIView(GenericAPIView):
    def delete(self, request, id):
        if not request.user.is_superuser and not request.user.is_staff:
            raise PermissionDenied("You do not have permission to perform this action!")
        recombee.send(DeleteUser(id))


class CurrentUserAPIView(GenericAPIView):
    """
    View cho việc lấy thông tin người dùng hiện tại. Để định danh người dùng, request cần được gửi kèm theo một access token, dưới dạng Bearer token được đính kèm trong header Authorization. Sau khi đã được xác thực thì request sẽ được thêm một trường user

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)

    Phương thức:
        get(request): Lấy thông tin người dùng hiện tại và trả về dữ liệu người dùng trong response.

    Kế thừa:
        GenericAPIView: API chung, tổng quát nhất
    """
    permission_classes = (IsAuthenticated,)

    def get(self, request):
        user = request.user
        serializer = ViewUserSerializer(user)
        return response.Response(serializer.data, status=status.HTTP_200_OK)


class AdminUpdateUserAPIView(UpdateAPIView):
    """
    View cho việc cập nhật thông tin người dùng bởi quản trị viên.

    Attributes:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        lookup_field (str): Trường dùng để tìm kiếm người dùng
        queryset (QuerySet): QuerySet chứa danh sách người dùng.
        serializer_class (UpdateUserSerializer): Serializer được sử dụng để chuyển đổi dữ liệu cập nhật người dùng.

    Methods:
        get_object():
            Trả về đối tượng người dùng cần cập nhật.
            Output:
                obj: Đối tượng người dùng.

            Exception:
                PermissionDenied: Nếu người dùng không có quyền truy cập

    Kế thừa:
        UpdateAPIView: API cập đối tượng

    """
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
    """
    View cho việc lấy danh sách địa chỉ của người dùng.

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        serializer_class (AddressSerializer): Serializer được sử dụng để chuyển đổi dữ liệu địa chỉ.

    Phương thức:
        get_queryset():
            Trả về QuerySet chứa danh sách địa chỉ của người dùng hiện tại.

            Input: none

            Output:
                queryset: QuerySet chứa danh sách địa chỉ.

    Kế thừa:
        ListAPIView: API truy vấn dưới dạng danh sách
    """
    permission_classes = (IsAuthenticated,)
    serializer_class = AddressSerializer

    def get_queryset(self):
        return Address.objects.filter(created_by=self.request.user)


class CreateAddressView(CreateAPIView):
    """
    View cho việc tạo địa chỉ mới.

    Thuộc tính:
        serializer_class (AddressSerializer): Serializer được sử dụng để chuyển đổi dữ liệu địa chỉ.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)

    Kế thừa:
        CreateAPIView: API tạo đối tượng

    """
    serializer_class = AddressSerializer
    permission_classes = (IsAuthenticated,)


class AddressDetailAPIView(RetrieveUpdateDestroyAPIView):
    """
    View cho việc xem, cập nhật và xóa thông tin một địa chỉ.

    Thuộc tính:
        serializer_class (AddressSerializer): Serializer được sử dụng để chuyển đổi dữ liệu địa chỉ.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        lookup_field (str): Trường dùng để tìm kiếm địa chỉ
        queryset (QuerySet): QuerySet chứa danh sách địa chỉ.

    Phương thức:
        get_object():
            Trả về đối tượng địa chỉ cần hiển thị hoặc cập nhật.
            Output:
                obj: Đối tượng địa chỉ.

            Exception:
                PermissionDenied: Nếu người dùng không có quyền truy cập vào địa chỉ.

    Kế thừa:
        RetrieveUpdateDestroyAPIView: API truy vấn thông tin chi tiết, cập nhật và xóa
    """
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
    """
    View cho việc lấy danh sách các nhà cung cấp thanh toán.

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        serializer_class (PaymentProviderSerializer): Serializer được sử dụng để chuyển đổi dữ liệu nhà cung cấp thanh toán.
        queryset (QuerySet): QuerySet chứa danh sách các nhà cung cấp thanh toán.

    Kế thừa:
        ListAPIView: API truy vấn dưới dạng danh sách

    """
    permission_classes = (IsAuthenticated,)
    serializer_class = PaymentProviderSerializer
    queryset = PaymentProvider.objects.all()


class PaymentListView(ListAPIView):
    """
    View cho việc lấy danh sách phương thức thanh toán của người dùng.

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        serializer_class (ViewPaymentSerializer): Serializer được sử dụng để chuyển đổi dữ liệu phương thức thanh toán.

    Phương thức:
        get_queryset():
            Trả về QuerySet chứa danh sách phương thức thanh toán của người dùng hiện tại.

            Input: none

            Output:
                queryset: QuerySet chứa danh sách phương thức thanh toán.

    Kế thừa:
        ListAPIView: API truy vấn dưới dạng danh sách

    """
    permission_classes = (IsAuthenticated,)
    serializer_class = ViewPaymentSerializer

    def get_queryset(self):
        return Payment.objects.filter(created_by=self.request.user)


class CreatePaymentView(CreateAPIView):
    """
    View cho việc tạo phương thức thanh toán mới.

    Thuộc tính:
        serializer_class (PaymentSerializer): Serializer được sử dụng để chuyển đổi dữ liệu phương thức thanh toán.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (đã được xác thực).

    Kế thừa:
        CreateAPIView: API tạo đối tượng
    """
    serializer_class = PaymentSerializer
    permission_classes = (IsAuthenticated,)


class PaymentDetailAPIView(RetrieveUpdateDestroyAPIView):
    """
    View chi tiết, cập nhật và xóa phương thức thanh toán.

    Thuộc tính:
        serializer_class (PaymentSerializer): Serializer được sử dụng để chuyển đổi dữ liệu phương thức thanh toán.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        lookup_field (str): Trường dùng để tìm kiếm phương thức thanh toán.
        queryset (QuerySet): QuerySet chứa danh sách các phương thức thanh toán.

    Phương thức:
        get_object():
            Trả về đối tượng phương thức thanh toán cần hiển thị hoặc cập nhật.
            Output:
                obj: Đối tượng phương thức thanh toán.

            Exception:
                PermissionDenied: Nếu người dùng không có quyền truy cập vào phương thức thanh toán.

    Kế thừa:
        RetrieveUpdateDestroyAPIView: API truy vấn thông tin chi tiết, cập nhật và xóa

    """
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
    """
    View danh sách các mục giỏ hàng.

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        serializer_class (ViewCartItemSerializer): Serializer được sử dụng để chuyển đổi dữ liệu mục giỏ hàng.

    Thuộc tính:
        get_queryset():
            Trả về QuerySet chứa danh sách giỏ hàng của người dùng hiện tại.

            Input: none

            Output:
                queryset: QuerySet chứa danh sách giỏ hàng.

    Kế thừa:
        ListAPIView: API truy vấn dưới dạng danh sách
    """
    permission_classes = (IsAuthenticated,)
    serializer_class = ViewCartItemSerializer

    def get_queryset(self):
        return CartItem.objects.filter(created_by=self.request.user)


class AddToCartView(GenericAPIView, RecombeeUserMixin):
    """
    Thêm sản phẩm vào giỏ hàng.

    Thuộc tính:
        serializer_class (CartItemSerializer): Serializer được sử dụng để chuyển đổi dữ liệu mục giỏ hàng.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)

    Phương thức:
        post(request):
            Thêm sản phẩm vào giỏ hàng và trả về kết quả.

            Input:
                request (Request): Đối tượng request chứa dữ liệu về sản phẩm được thêm vào giỏ hàng.

            Output:
                Response: Đối tượng response chứa dữ liệu của mục giỏ hàng đã được thêm vào.

            Raises:
                ValidationError: Nếu số lượng sản phẩm trong kho không đủ (tự động đặt lại số lượng sản phẩm trong giỏ hàng của người dùng) hoặc thông tin không hợp lệ.

    Kế thừa:
        GenericAPIView: API chung, tổng quát nhất

    """
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
            self.add_cart(request.user, product)
            return response.Response(serializer.data, status=status.HTTP_200_OK)

        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class MakeOrderFromCartView(GenericAPIView, RecombeeUserMixin):
    """
    Tạo đơn hàng từ giỏ hàng.

    Thuộc tính:
        serializer_class (OrderSerializer): Serializer được sử dụng để chuyển đổi dữ liệu đơn hàng.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)

    Phương thức:
        update_variation_qty(cart_items):
            Cập nhật số lượng hàng tồn kho sau khi tạo đơn hàng.

            Input:
                cart_items (QuerySet): QuerySet chứa các mục giỏ hàng cần được cập nhật.

            Output: none


        remove_all_cart_items(cart_items):
            Xóa tất cả các mục trong giỏ hàng sau khi tạo đơn hàng.

            Input:
                cart_items (QuerySet): QuerySet chứa các mục giỏ hàng.


        post(request):
            Tạo đơn hàng từ giỏ hàng và trả về kết quả.

            Input:
                request (Request): Đối tượng request chứa dữ liệu đơn hàng từ giỏ hàng.

            Output:
                Response: Đối tượng response chứa dữ liệu của đơn hàng đã được tạo.

            Raises:
                ValidationError: Nếu không có mục nào trong giỏ hàng, hoặc thời điểm đặt không có đủ số lượng tồn kho, hoặc thông tin không hợp lệ.

    Kế thừa:
        GenericAPIView: API chung, tổng quát nhất
    """
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
        serializer = self.serializer_class(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            print(str(serializer.instance.created_at.timestamp()))
            self.make_order(request.user, cart_items, serializer.instance.created_at.timestamp())
            self.update_variation_qty(cart_items)
            self.remove_all_cart_items(cart_items)
            return response.Response(serializer.data, status=status.HTTP_200_OK)

        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CartItemDetailAPIView(RetrieveDestroyAPIView, RecombeeUserMixin):
    """
    Xem và xóa mục giỏ hàng. Chỉ cho phép thay đổi số lượng hoặc xóa, do đó không đi kèm với cập nhật các mục trong giỏ hàng ở View này

    Thuộc tính:
        serializer_class (ViewCartItemSerializer): Serializer được sử dụng để chuyển đổi dữ liệu mục giỏ hàng.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        lookup_field (str): Trường sử dụng để tìm kiếm mục giỏ hàng.
        queryset (QuerySet): QuerySet chứa tất cả các mục giỏ hàng.

    Phương thức:
        get_object():
            Trả về đối tượng giỏ hàng cần hiển thị hoặc cập nhật.
            Output:
                obj: Đối tượng giỏ hàng.

            Exception:
                PermissionDenied: Nếu người dùng không có quyền truy cập vào giỏ hàng.

    Kế thừa:
        RetrieveDestroyAPIView: API truy vấn thông tin chi tiết và xóa đối tượng
    """
    serializer_class = ViewCartItemSerializer
    permission_classes = (IsAuthenticated,)
    lookup_field = "id"
    queryset = CartItem.objects.all()

    def get_object(self):
        obj = super().get_object()
        if obj.created_by != self.request.user:
            raise PermissionDenied("You do not have permission to access this.")
        return obj

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        self.delete_cart(request.user, instance.product)
        self.perform_destroy(instance)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChangeQtyCartItemAPIView(UpdateAPIView, RecombeeUserMixin):
    """
    Thay đổi số lượng mục giỏ hàng.

    Thuộc tính:
        serializer_class (CartItemSerializer): Serializer được sử dụng để chuyển đổi dữ liệu mục giỏ hàng.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        lookup_field (str): Trường sử dụng để tìm kiếm mục giỏ hàng.
        queryset (QuerySet): QuerySet chứa tất cả các mục giỏ hàng.

    Phương thức:
        get_object():
            Trả về đối tượng mục giỏ hàng cần hiển thị hoặc cập nhật.
            Output:
                obj: Đối tượng mục giỏ hàng.

            Exception:
                PermissionDenied: Nếu người dùng không có quyền truy cập vào mục giỏ hàng.


        perform_update(serializer):
            Thực hiện cập nhật số lượng mục giỏ hàng.
            Input:
                serializer (CartItemSerializer): Serializer chứa dữ liệu mục giỏ hàng cần cập nhật.

            Raises:
                serializers.ValidationError: Nếu hành động không hợp lệ hoặc số lượng mục giỏ hàng vượt quá số lượng tồn kho.

    Kế thừa:
        UpdateAPIView: API cập đối tượng
    """
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
        self.add_cart(self.request.user, instance.product, amount=(1 if action == 'inc' else -1))


class FavoriteItemListView(ListAPIView):
    """
    Xem danh sách các mục yêu thích.

    Thuộc tính:
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        serializer_class (ViewFavoriteItemSerializer): Serializer được sử dụng để chuyển đổi dữ liệu mục yêu thích.

    Phương thức:
        get_queryset():
            Trả về QuerySet chứa danh sách các mục yêu thích của người dùng hiện tại.

            Input: none

            Output:
                queryset: QuerySet chứa danh sách các mục yêu thích.


    Kế thừa:
        ListAPIView: API truy vấn dưới dạng danh sách
    """
    permission_classes = (IsAuthenticated,)
    serializer_class = ViewFavoriteItemSerializer

    def get_queryset(self):
        return FavoriteItem.objects.filter(created_by=self.request.user)


class AddItemToFavoriteView(CreateAPIView, RecombeeUserMixin):
    """
    Thêm mục vào danh sách yêu thích.

    Thuộc tính:
        serializer_class (FavoriteItemSerializer): Serializer được sử dụng để chuyển đổi dữ liệu mục yêu thích.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)

    Phương thức:
        post(request, *args, **kwargs):
            Tạo một mục yêu thích mới cho người dùng hiện tại.

            Input:
                request (Request): Đối tượng request chứa dữ liệu yêu cầu.
                *args: List các đối số không đặt tên.
                **kwargs: Dictionary các đối số đặt tên.

            Output:
                Response: Đối tượng response chứa dữ liệu của item vừa được thêm vào danh sách yêu thích

            Raises:
                ValidationError: Nếu mục yêu thích đã tồn tại trong danh sách yêu thích của người dùng.

    Kế thừa:
        CreateAPIView: API tạo đối tượng

    """
    serializer_class = FavoriteItemSerializer
    permission_classes = (IsAuthenticated,)

    def post(self, request, *args, **kwargs):
        user = request.user
        product = Product.objects.get(id=request.data['product'])
        instance = FavoriteItem.objects.filter(created_by=user, product=product).first()
        # Check if favorite item already exists in user's favorite list
        if instance is not None:
            # If true then throw error
            raise serializers.ValidationError("Item's already in favorite items")
        else:
            # Else add to favorite list
            serializer = self.serializer_class(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            self.add_bookmark(request.user, product)
            return response.Response(serializer.data, status=status.HTTP_200_OK)

        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class DeleteFavoriteItemView(GenericAPIView, RecombeeUserMixin):
    """
    Xóa mục khỏi danh sách yêu thích. Không có phương thức cập nhật và xem chi tiết vì không cần thiết.

    Thuộc tính:
        serializer_class (FavoriteItemSerializer): Serializer được sử dụng để chuyển đổi dữ liệu mục yêu thích.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated,)
        queryset (QuerySet): QuerySet chứa tất cả các mục yêu thích.
        lookup_field (str): Trường dùng để tìm kiếm mục yêu thích.

    Phương thức:
        get_object():
            Trả về đối tượng mục yêu thích cần xóa
            Output:
                obj: Đối tượng mục yêu thích.

            Exception:
                PermissionDenied: Nếu người dùng không có quyền truy cập vào mục yêu thích.

    Kế thừa:
        DestroyAPIView: API xóa đối tượng

    """
    serializer_class = FavoriteItemSerializer
    permission_classes = (IsAuthenticated,)
    queryset = FavoriteItem.objects.all()
    lookup_field = 'id'

    def get_object(self):
        obj = super().get_object()

    def delete(self, request, id, format=None):
        product = Product.objects.get(id=id)
        favorite = FavoriteItem.objects.filter(created_by__id=request.user.id, product=product)
        if not favorite:
            raise PermissionDenied(
                "You do not have permission to access this or you haven't like yet or wrong product id")

        favorite.delete()
        self.delete_bookmark(request.user, product)

        return Response({'message': 'Favorite item deleted successfully'})


class VoucherView(ListAPIView):
    """
    Xem danh sách các phiếu giảm giá.

    Thuộc tính:
        queryset (QuerySet): QuerySet chứa tất cả các phiếu giảm giá.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated, IsAdminUser)
        serializer_class (VoucherSerializer): Serializer được sử dụng để chuyển đổi dữ liệu phiếu giảm giá.

    Kế thừa:
        ListAPIView: API truy vấn dưới dạng danh sách

    """
    queryset = Voucher.objects.all()
    permission_classes = (IsAuthenticated, IsAdminUser)
    serializer_class = VoucherSerializer


class CreateRewardVoucher(GenericAPIView):
    def post(self, request):
        reward_list = [[2, 1000], [3, 1500], [5, 2500], [7, 4000], [10, 8000], [15, 15000]]
        level = int(self.request.data.get('level'))

        if level is not None:
            reward = reward_list[level - 1]
            exist_voucher = Voucher.objects.filter(owner=self.request.user, level=level)
            if len(exist_voucher) == 0:
                if self.request.user.points < reward[1]:
                    raise serializers.ValidationError("Not enough points")
                Voucher.objects.create(
                    discount=reward[0],
                    from_date=(datetime.now() - timedelta(days=1)).date(),
                    to_date=(datetime.now() + timedelta(days=10000)).date(),
                    code=''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(8)),
                    inventory=1,
                    level=level,
                    owner=self.request.user
                )
            else:
                raise serializers.ValidationError("Voucher already exists")
        else:
            if not self.request.user.is_superuser and not self.request.user.is_staff:
                raise PermissionDenied("You do not have permission to perform this action")
        return Response({"message": 'success'}, status=status.HTTP_200_OK)


class CreateVoucherView(CreateAPIView):
    """
    View cho việc tạo voucher mới.

    Thuộc tính:
        serializer_class (PaymentSerializer): Serializer được sử dụng để chuyển đổi dữ liệu voucher.
        permission_classes (tuple): Danh sách các lớp kiểm tra quyền truy cập cho view (IsAuthenticated, IsAdminUser)

    Kế thừa:
        CreateAPIView: API tạo đối tượng

    """
    serializer_class = VoucherSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)


class VoucherDetailAPIView(IncludeDeleteMixin, RetrieveUpdateDestroyAPIView):
    """
    View cung cấp chức năng để lấy thông tin, cập nhật và xóa một phiếu giảm giá cụ thể.

    Thuộc tính:
        serializer_class (VoucherSerializer): Serializer sử dụng để chuyển đổi dữ liệu phiếu giảm giá.
        permission_classes (tuple): Tuple chứa các lớp kiểm tra quyền truy cập được áp dụng cho view này (IsAuthenticated, IsAdminUser).
        lookup_field (str): Trường dùng để tìm kiếm phiếu giảm giá
        queryset (QuerySet): QuerySet chứa tất cả các phiếu giảm giá

    Kế thừa:
        IncludeDeleteMixin: hỗ trợ truy vấn và thực hiện soft delete
        RetrieveUpdateDestroyAPIView: API truy vấn thông tin chi tiết, cập nhật và xóa
    """
    serializer_class = VoucherSerializer
    permission_classes = (IsAuthenticated, IsAdminUser)
    lookup_field = "id"
    queryset = Voucher.objects.all()
    query_model = Voucher


class GetVoucherFromCodeView(RetrieveAPIView):
    """
    View cung cấp chức năng để lấy thông tin về một phiếu giảm giá dựa trên mã code. View này được sử dụng để người dùng có thể lấy và áp dụng mã giảm giá miễn là họ nhập đúng mã

    Thuộc tính:
        serializer_class (VoucherSerializer): Serializer sử dụng để chuyển đổi dữ liệu phiếu giảm giá.
        permission_classes (tuple): Tuple chứa các lớp kiểm tra quyền truy cập được áp dụng cho view này (IsAuthenticated,).

    Phương thức:
        get_object():
            Phương thức lấy đối tượng phiếu giảm giá từ mã code được truyền qua query parameters.

            Output:
                Voucher: Đối tượng phiếu giảm giá tương ứng với mã code.

            Raises:
                ValidationError: Nếu không tìm thấy phiếu giảm giá với mã code được truyền.

    Kế thừa:
        RetrieveAPIView: API truy vấn thông tin chi tiết

    """
    serializer_class = VoucherSerializer
    permission_classes = (IsAuthenticated,)

    def get_object(self):
        code = self.request.query_params.get('code')
        instance = Voucher.objects.filter(code=code).first()
        current_time = timezone.now().date()
        if instance.from_date > current_time or instance.to_date < current_time:
            raise serializers.ValidationError("Voucher is expired")
        if instance is None:
            raise serializers.ValidationError(f'No voucher found')
        return instance


class FileUploadView(GenericAPIView):
    """
    Lớp FileUploadView là một generic view cung cấp chức năng tải lên file. File sẽ được tải lên AWS S3 Bucket, sau đó trả về kết quả là url đến file đó (thông qua AWS CloudFront distribution)

    Thuộc tính:
        permission_classes (tuple): Tuple chứa các lớp kiểm tra quyền truy cập được áp dụng cho view này (IsAuthenticated,).

    Phương thức:
        post(request):
            Phương thức xử lý một request POST để tải lên file.
            Input:
                request (HttpRequest): Đối tượng HttpRequest chứa từ client.

            Output:
                Response: Url của file vừa được upload

            Raises:
                ValidationError: Nếu dữ liệu yêu cầu không hợp lệ.

    Kế thừa:
        GenericAPIView: API chung, tổng quát nhất

    """
    permission_classes = (IsAuthenticated,)

    def post(self, request):
        serializer = FileUploadSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            response_data = serializer.data
            return Response(response_data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class SaleStatisticsAPIView(GenericAPIView):
    """
    Lớp SaleStatisticsAPIView là một generic view cung cấp chức năng thống kê doanh số bán hàng.

    Thuộc tính:
        serializer_class (Serializer): Serializer được sử dụng để chuyển đổi dữ liệu đơn hàng.
        permission_classes (tuple): Tuple chứa các lớp kiểm tra quyền truy cập được áp dụng cho view này (IsAuthenticated, IsAdminUser).

    Phương thức:
        get_df_sum(queryset):
            Trả về một DataFrame và tổng doanh số bán hàng.
            Input:
                queryset (QuerySet): Đối tượng QuerySet chứa dữ liệu các đơn hàng.

            Output:
                DataFrame: Đối tượng DataFrame chứa tổng doanh số theo tháng, và tổng doanh số

        analyze(prev_queryset, queryset):
            Phân tích và tính toán các chỉ số thống kê từ dữ liệu đơn hàng.

            Input:
                prev_queryset (QuerySet): Đối tượng QuerySet chứa dữ liệu đơn hàng của giai đoạn trước.
                queryset (QuerySet): Đối tượng QuerySet chứa dữ liệu đơn hàng của giai đoạn hiện tại.

            Output:
                dict: Dictionary chứa các chỉ số thống kê, bao gồm tổng doanh số, tổng doanh số theo tháng và tăng trưởng so với giai đoạn trước.


        get(request):
            Xử lý yêu cầu GET để thống kê doanh số bán hàng.
            Input:
                request (HttpRequest): Đối tượng HttpRequest chứa từ client.

            Output:
                Response: Đối tượng Response chứa kết quả thống kê doanh số bán hàng.

            Raises:
                ValidationError: Nếu định dạng ngày không hợp lệ hoặc khoảng thời gian vượt quá 6 tháng.

    Note:
        Lớp này sử dụng thư viện pandas.

    Kế thừa:
        GenericAPIView: API chung, tổng quát nhất

    """
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
            growth = int(float(total) * 100 / float(prev_total) - 100)
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
    """
    Lớp TopProductStatisticsAPIView là một generic view cung cấp chức năng thống kê sản phẩm bán chạy nhất theo tuần, tháng, quý hoặc năm.

    Thuộc tính:
        serializer_class (Serializer): Serializer được sử dụng để chuyển đổi dữ liệu đơn hàng.
        permission_classes (tuple): Tuple chứa các lớp kiểm tra quyền truy cập được áp dụng cho view này. (IsAuthenticated, IsAdminUser)

    Phương thức:
        analyze(queryset):
            Phân tích và tính toán các chỉ số thống kê từ dữ liệu đơn hàng.

            Input:
                queryset (QuerySet): Đối tượng QuerySet chứa dữ liệu đơn hàng.

            Output:
                list: Danh sách các sản phẩm bán chạy nhất, được sắp xếp theo doanh thu và số lượng bán giảm dần.


        get(request):
            Xử lý yêu cầu GET để thống kê sản phẩm bán chạy nhất.

            Args:
                request (HttpRequest): Đối tượng HttpRequest từ client.

            Returns:
                Response: Đối tượng Response chứa kết quả thống kê sản phẩm bán chạy nhất.

            Raises:
                ValidationError: Nếu định dạng khoảng thời gian không hợp lệ


    Note:
        - Lớp này sử dụng pandas

    Kế thừa:
        GenericAPIView: API chung, tổng quát nhất
    """
    serializer_class = OrderSerializer
    permission_classes = (IsAuthenticated,)

    def analyze(self, queryset):
        serializer = self.serializer_class(queryset, many=True)
        if len(queryset) == 0:
            return
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
                price = float(order_detail['price'])
                total = qty * price
                if product_id in top_products:
                    sales = top_products[product_id].get('sales')
                    revenue = top_products[product_id].get('revenue')
                    top_products[product_id] = {
                        'sales': sales + qty,
                        'revenue': float(revenue) + total
                    }
                else:
                    top_products[product_id] = {
                        'sales': qty,
                        'revenue': float(total)
                    }

        top_products_df = pd.DataFrame.from_dict(top_products, orient='index')
        top_products_df = top_products_df.sort_values(by=['revenue', 'sales'], ascending=[False, False])
        res = top_products_df.reset_index().rename(columns={'index': 'product'}).to_dict(orient='records')
        for item in res:
            item['product'] = ListProductSerializer(instance=Product.objects.get(id=item['product']),
                                                    context={'request': self.request}).data
        return res

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

        res = self.analyze(queryset)
        if res:
            return response.Response(self.analyze(queryset), status=status.HTTP_200_OK)
        else:
            return response.Response({'Message': 'No data'}, status=status.HTTP_200_OK)


class TopCategoriesAPIView(GenericAPIView):
    """
    Lớp TopCategoriesAPIView là một generic view cung cấp chức năng thống kê danh mục bán chạy nhất. Đồng thời đưa ra chỉ số phần trăm khách hàng mới và khách khác quay lại (returning)

    Thuộc tính:
        serializer_class (Serializer): Serializer được sử dụng để chuyển đổi dữ liệu đơn hàng.
        permission_classes (tuple): Tuple chứa các lớp kiểm tra quyền truy cập được áp dụng cho view này (IsAuthenticated, IsAdminUser).

    Phương thức:
        analyze(queryset):
            Phân tích và tính toán các chỉ số thống kê từ dữ liệu đơn hàng.

            Input:
                queryset (QuerySet): Đối tượng QuerySet chứa dữ liệu đơn hàng.

            Output:
                tuple: Tuple chứa danh sách các danh mục sản phẩm phổ biến nhất, tỷ lệ khách hàng mới và tỷ lệ khách hàng quay lại.


        get(request):
            Xử lý yêu cầu GET để thống kê danh mục sản phẩm phổ biến nhất.

            Input:
                request (HttpRequest): Đối tượng HttpRequest chứa yêu cầu từ client.

            Output:
                Response: Đối tượng Response chứa kết quả thống kê danh mục sản phẩm phổ biến nhất.

    Note:
        - Lớp này sử dụng pandas

    Kế thừa:
        GenericAPIView: API chung, tổng quát nhất
    """

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
            obj["category"] = CategorySerializer(instance=Category.objects.get(id=obj['category'])).data

        return arr, new_buyers_percent, returning_percent

    def get(self, request):
        queryset = Order.objects.filter(status='Success')
        data, new_buyers_percent, returning_percent = self.analyze(queryset)
        return response.Response({
            'data': data,
            'new_buyers_percent': new_buyers_percent,
            'returning_percent': returning_percent
        }, status=status.HTTP_200_OK)


class GetProductFilter(IncludeDeleteMixin, GenericAPIView):
    query_model = Product

    def get(self, request, *args, **kwargs):
        category_id = kwargs.get('id')
        if category_id is not None:
            queryset = self.get_queryset().filter(category_id=category_id)
        else:
            queryset = self.get_queryset()
        result = queryset.aggregate(max_price=Max('price'), min_price=Min('price'))
        width = queryset.order_by('width').values_list('width', flat=True).distinct('width')
        height = queryset.order_by('height').values_list('height', flat=True).distinct('height')
        length = queryset.order_by('length').values_list('length', flat=True).distinct('length')
        weight = queryset.order_by('weight').values_list('weight', flat=True).distinct('weight')
        material = queryset.order_by('material').values_list('material', flat=True).distinct('material')

        include_delete = self.request.query_params.get('include_delete')
        if include_delete:
            variations = Variation.objects.all()
        else:
            variations = Variation.undeleted_objects.all()

        variations = variations.filter(product__in=queryset).order_by('name').values_list(
            'name', flat=True).distinct('name')

        return Response({
            'max_price': result['max_price'],
            'min_price': result['min_price'],
            'width': list(width),
            'height': list(height),
            'length': list(length),
            'weight': list(weight),
            'material': list(material),
            'variation': list(variations)
        }, status=status.HTTP_200_OK)


class SuggestVoucher(GenericAPIView):
    def get(self, request, *args, **kwargs):
        if not request.user.is_superuser and not request.user.is_staff:
            raise PermissionDenied("You do not have permission to access this")

        ordered_product = OrderDetail.objects.values_list('product__id', flat=True)

        current_time = datetime.now()
        query_set = Product.undeleted_objects.exclude(id__in=ordered_product).filter(
            created_at__lte=current_time - timedelta(days=90))
        serializer = ListProductSerializer(data=query_set, many=True, context={'request': request})
        serializer.is_valid()
        return Response(serializer.data, status=status.HTTP_200_OK)

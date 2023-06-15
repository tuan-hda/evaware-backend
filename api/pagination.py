from rest_framework import pagination, serializers

from api.models import OrderDetail
from api.serializers import VariationSerializer, ListProductSerializer


class CustomPageNumberPagination(pagination.PageNumberPagination):
    """
    Lớp custom cho phân trang cho Django REST Framework.

    Thuộc tính:
        page_size (int): Số lượng item trên mỗi trang
        page_size_query_param (str): Tên tham số truy vấn số lượng item của request
        max_page_size (int): Số lượng item tối đa trên mỗi trang (mặc định: 10).
        page_query_param (str): Tên tham số truy vấn số trang hiện tại (mặc định: 'p').

    """
    page_size = 10
    page_size_query_param = 'count'
    max_page_size = 100
    page_query_param = 'p'


class ViewOrderDetailAltSerializer(serializers.ModelSerializer):
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
    product = ListProductSerializer()

    class Meta:
        model = OrderDetail
        fields = "__all__"

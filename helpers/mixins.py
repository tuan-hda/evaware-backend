from rest_framework.exceptions import PermissionDenied

from api.models import Product


class IncludeDeleteMixin:
    """
    Mixin thêm hàm cho phép truy vấn các sản phẩm đã bị xóa (soft delete) trong danh sách (Chỉ có staff mới được truy vấn). Mixin cũng thay thế hàm perform_destroy để ghi đè hàm khác. Mixin này nên được kế thừa đầu tiên, để nó ghi đè các phương thức từ các lớp khác.

    Phương thức:
        get_queryset():
            Trả về queryset của các sản phẩm, bao gồm hoặc không bao gồm các sản phẩm đã bị xóa.

            Input: none

            Output:
                QuerySet: queryset của các sản phẩm.

            Raises:
                PermissionDenied: Nếu người dùng là khách hàng, họ không có quyền truy cập vào các sản phẩm đã bị xóa.


        perform_destroy(instance):
            Thực hiện xóa (soft delete) một sản phẩm.

            Input:
                instance (Product): Sản phẩm cần bị xóa.

            Output: none

    """

    def get_queryset(self):
        include_delete = self.request.query_params.get('include_delete')
        if include_delete:
            user = self.request.user
            if not user.is_staff:
                raise PermissionDenied("You don't have permission to access this")
            queryset = Product.objects.all()
        else:
            queryset = Product.undeleted_objects.all()

        return queryset

    def perform_destroy(self, instance):
        instance.soft_delete()

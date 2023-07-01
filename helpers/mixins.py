from recombee_api_client.api_requests import SetItemValues, DeleteItem
from recombee_api_client.exceptions import APIException
from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from api.models import Product
from evaware_backend.settings import recombee


class IncludeDeleteMixin:
    """
    Mixin thêm hàm cho phép truy vấn các đối tượng đã bị xóa (soft delete) trong danh sách (Chỉ có staff mới được truy vấn). Mixin cũng thay thế hàm perform_destroy để ghi đè hàm khác. Mixin này nên được kế thừa đầu tiên, để nó ghi đè các phương thức từ các lớp khác.

    Phương thức:
        get_queryset(Model):
            Trả về queryset của các đối tượng, bao gồm hoặc không bao gồm các đối tượng đã bị xóa.

            Input: none

            Output:
                QuerySet: queryset của các đối tượng.

            Raises:
                PermissionDenied: Nếu người dùng là khách hàng, họ không có quyền truy cập vào các đối tượng đã bị xóa.


        perform_destroy(instance):
            Thực hiện xóa (soft delete) một đối tượng.

            Input:
                instance (Model): đối tượng cần bị xóa.

            Output: none

    """

    def get_queryset(self):
        include_delete = self.request.query_params.get('include_delete')
        if include_delete:
            user = self.request.user
            if not user.is_staff:
                raise PermissionDenied("You don't have permission to access this")
            queryset = self.query_model.objects.all()
        else:
            queryset = self.query_model.undeleted_objects.all()

        return queryset

    def perform_destroy(self, instance):
        instance.soft_delete()


class RecombeeProductMixin:
    def set_recombee_item(self, product, is_deleted=False, review=0, old_review=0, cascade_create=False):
        product_id = product.id

        if review != 0:
            if old_review == 0:
                reviews_count = product.reviews_count + (1 if review > 0 else -1)
            else:
                reviews_count = product.reviews_count
            avg_rating = (product.avg_rating * product.reviews_count + review - old_review) / reviews_count
        else:
            reviews_count = product.reviews_count
            avg_rating = product.avg_rating

        try:
            recombee.send(SetItemValues(str(product_id),
                                        {
                                            "name": product.name,
                                            "desc": product.desc,
                                            "price": float(product.price),
                                            "category_id": product.category_id,
                                            "category_name": product.category.name,
                                            "thumbnail": product.thumbnail,
                                            "reviews_count": reviews_count,
                                            "discount": product.discount,
                                            "avg_rating": float(avg_rating),
                                            "is_deleted": is_deleted
                                        },
                                        cascade_create=cascade_create
                                        ))
            return 1
        except APIException as e:
            print(e)
            return 0

    def recombee_network_error(self):
        return Response(data={"message": "Recombee network error - Sent request failed"},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def delete_recombee_item(self, item_id):
        recombee.send(DeleteItem(str(item_id)))

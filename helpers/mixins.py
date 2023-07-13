from recombee_api_client.api_requests import (
    SetItemValues,
    DeleteItem,
    SetUserValues,
    AddDetailView,
    AddCartAddition,
    DeleteCartAddition,
    AddPurchase,
    Batch,
    DeletePurchase,
    AddBookmark,
    DeleteBookmark,
    AddRating,
    DeleteRating,
    RecommendItemsToItem,
    RecommendItemsToUser,
    SearchItems,
)
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
        include_delete = self.request.query_params.get("include_delete")
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


class RecombeeTimeoutWrapper:
    @staticmethod
    def wrap(r):
        r.timeout = 5000
        return r


class RecombeeProductMixin:
    def set_recombee_item(
        self, product, is_deleted=False, review=0, old_review=0, cascade_create=False
    ):
        product_id = product.id

        if review != 0:
            if old_review == 0:
                reviews_count = product.reviews_count + (1 if review > 0 else -1)
            else:
                reviews_count = product.reviews_count
            if reviews_count is None or reviews_count == 0:
                reviews_count = 1

            avg_rating = (
                product.avg_rating
                * (product.reviews_count if product.reviews_count is not None else 0)
                + review
                - old_review
            ) / reviews_count
        else:
            reviews_count = product.reviews_count
            avg_rating = product.avg_rating

        try:
            recombee.send(
                RecombeeTimeoutWrapper.wrap(
                    SetItemValues(
                        str(product_id),
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
                            "is_deleted": is_deleted,
                        },
                        cascade_create=cascade_create,
                    )
                )
            )
            return 1
        except APIException as e:
            print(e)
            return 0

    def recombee_network_error(self):
        return Response(
            data={"message": "Recombee network error - Sent request failed"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    def delete_recombee_item(self, item_id):
        recombee.send(RecombeeTimeoutWrapper.wrap(DeleteItem(str(item_id))))


class RecombeeUserMixin:
    def set_recombee_user(self, user, cascade_create=False):
        data = {
            "gender": None,
            "avatar": "https://static.thenounproject.com/png/5100711-200.png",
        }
        if user.gender is not None:
            data["gender"] = user.gender
        if user.avatar is not None and user.avatar != "":
            data["avatar"] = user.avatar

        try:
            recombee.send(
                RecombeeTimeoutWrapper.wrap(
                    SetUserValues(user.email, data, cascade_create=cascade_create)
                )
            )
            return 1
        except APIException as e:
            print(e)
            return 0

    def view_detail(self, user, product, recomm_id=None):
        recombee.send(
            RecombeeTimeoutWrapper.wrap(
                AddDetailView(
                    user.email,
                    str(product.id),
                    recomm_id=recomm_id,
                    cascade_create=True,
                )
            )
        )

    def add_cart(self, user, product, recomm_id=None, amount=1):
        if amount < 0:
            amount = 0
        discount_price = float(product.price) * (1 - product.discount / 100)
        recombee.send(
            RecombeeTimeoutWrapper.wrap(
                AddCartAddition(
                    user.email,
                    str(product.id),
                    recomm_id=recomm_id,
                    cascade_create=True,
                    amount=amount,
                    price=float(discount_price * amount),
                )
            )
        )

    def delete_cart(self, user, product):
        recombee.send(
            RecombeeTimeoutWrapper.wrap(DeleteCartAddition(user.email, str(product.id)))
        )

    def get_add_purchase(self, user, product, timestamp, amount=1):
        discount_price = float(product.price) * (1 - product.discount / 100)
        return AddPurchase(
            user.email,
            str(product.id),
            timestamp=timestamp,
            amount=amount,
            price=float(discount_price * amount),
        )

    def get_delete_purchase(self, user, product, timestamp):
        return DeletePurchase(user.email, str(product.id), timestamp=timestamp)

    def make_order(self, user, cartitems, timestamp):
        requests = []
        for cartitem in cartitems:
            requests.append(
                self.get_add_purchase(
                    user, cartitem.product, timestamp, amount=cartitem.qty
                )
            )
        recombee.send(RecombeeTimeoutWrapper.wrap(Batch(requests)))

    def cancel_order(self, user, cartitems, timestamp):
        requests = []
        for cartitem in cartitems:
            requests.append(self.get_delete_purchase(user, cartitem.product, timestamp))
        recombee.send(RecombeeTimeoutWrapper.wrap(Batch(requests)))

    def add_bookmark(self, user, product):
        recombee.send(
            RecombeeTimeoutWrapper.wrap(AddBookmark(user.email, str(product.id)))
        )

    def delete_bookmark(self, user, product):
        recombee.send(
            RecombeeTimeoutWrapper.wrap(DeleteBookmark(user.email, str(product.id)))
        )

    def add_rating(self, user, product, rating, timestamp):
        recombee.send(
            RecombeeTimeoutWrapper.wrap(
                AddRating(user.email, str(product.id), 0.5 * (rating - 3), timestamp)
            )
        )

    def delete_rating(self, user, product, timestamp):
        recombee.send(
            RecombeeTimeoutWrapper.wrap(
                DeleteRating(user.email, str(product.id), timestamp)
            )
        )


class RecombeeNetworkError:
    @classmethod
    def recombee_network_error(cls):
        return Response(
            data={"message": "Recombee network error - Sent request failed"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )


class RecombeeRecommendMixin:
    def recommend_items_to_item(self, product, user, count):
        return recombee.send(
            RecombeeTimeoutWrapper.wrap(
                RecommendItemsToItem(str(product.id), user.email, count)
            )
        )

    def recommend_items_to_user(self, user, count):
        return recombee.send(
            RecombeeTimeoutWrapper.wrap(RecommendItemsToUser(user.email, count))
        )

    def search_items(self, user, search_query, count):
        return recombee.send(
            RecombeeTimeoutWrapper.wrap(SearchItems(user, search_query, count))
        )

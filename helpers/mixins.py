from rest_framework.exceptions import PermissionDenied

from api.models import Product


class IncludeDeleteMixin:
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

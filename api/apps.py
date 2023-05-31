from django.apps import AppConfig


class ApiConfig(AppConfig):
    """
    Cấu hình ứng dụng API trong Django.

    Thuộc tính:
        default_auto_field (str): Tên của trường tự động
        name (str): Tên của ứng dụng

    """
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api'

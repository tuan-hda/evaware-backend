from rest_framework import pagination


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
    max_page_size = 10
    page_query_param = 'p'

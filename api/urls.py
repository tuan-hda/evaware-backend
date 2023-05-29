from django.contrib import admin
from django.urls import path
from .views import ProductView, CreateProductView, ProductDetailAPIView, CategoryView, CreateCategoryView, \
    CategoryDetailAPIView, UserView, CreateVariationView, VariationDetailAPIView, CreateOrderAPIView, OrderView, \
    OrderDetailAPIView

urlpatterns = [
    path('product/', ProductView.as_view(), name='get-all-products'),
    path('product/create', CreateProductView.as_view()),
    path('product/<int:id>', ProductDetailAPIView.as_view(), name='product'),
    path('category/', CategoryView.as_view(), name='get-all-categories'),
    path('category/create', CreateCategoryView.as_view(), name='create-category'),
    path('category/<int:id>', CategoryDetailAPIView.as_view(), name='category'),
    path('variation/create', CreateVariationView.as_view(), name='create-variation'),
    path('variation/<int:id>', VariationDetailAPIView.as_view(), name='variation'),
    path('order/', OrderView.as_view(), name='get-all-orders'),
    path('order/create', CreateOrderAPIView.as_view(), name='create-order'),
    path('order/<int:id>', OrderDetailAPIView.as_view(), name='order'),
    path('user/', UserView.as_view(), name='get-all-users')
]

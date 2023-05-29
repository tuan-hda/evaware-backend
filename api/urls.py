from django.contrib import admin
from django.urls import path
from .views import ProductView, CreateProductView, ProductDetailAPIView

urlpatterns = [
    path('product/', ProductView.as_view(), name='get-all-products'),
    path('product/create', CreateProductView.as_view()),
    path('product/<int:id>', ProductDetailAPIView.as_view(), name='product'),
]

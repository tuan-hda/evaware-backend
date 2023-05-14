from django.contrib import admin
from django.urls import path
from .views import ProductView, CreateProductView

urlpatterns = [
    path('product', ProductView.as_view()),
    path('product/create', CreateProductView.as_view())
]

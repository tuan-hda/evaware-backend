from django.contrib import admin
from django.urls import path
from .views import ProductView, CreateProductView, ProductDetailAPIView, CategoryView, CreateCategoryView, \
    CategoryDetailAPIView, UserView, CreateVariationView, VariationDetailAPIView, CreateOrderAPIView, OrderView, \
    OrderDetailAPIView, CreateReviewAPIView, ReviewDetailAPIView, UserUpdateProfileAPIView, CurrentUserAPIView, \
    AdminUpdateUserAPIView, AddressListView, CreateAddressView, AddressDetailAPIView, PaymentProviderListView, \
    PaymentListView, CreatePaymentView, PaymentDetailAPIView, CartItemListView, AddToCartView, CartItemDetailAPIView, \
    ChangeQtyCartItemAPIView, FavoriteItemListView, AddItemToFavoriteView, DeleteFavoriteItemView, \
    MakeOrderFromCartView, CreateVoucherView, VoucherView, VoucherDetailAPIView, GetVoucherFromCodeView

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
    path('order/make-order-from-cart', MakeOrderFromCartView.as_view(), name='make-order-from-cart'),
    path('review/create', CreateReviewAPIView.as_view(), name='create-review'),
    path('review/<int:id>', ReviewDetailAPIView.as_view(), name='review'),
    path('user/', UserView.as_view(), name='get-all-users'),
    path('user/current', CurrentUserAPIView.as_view(), name='user'),
    path('user/<int:id>', UserUpdateProfileAPIView.as_view(), name='update-profile'),
    path('user/<int:id>/admin', AdminUpdateUserAPIView.as_view(), name='update-user-admin'),
    path('address/', AddressListView.as_view(), name='get-user-address'),
    path('address/create', CreateAddressView.as_view(), name='create-address'),
    path('address/<int:id>', AddressDetailAPIView.as_view(), name='address'),
    path('payment-providers/', PaymentProviderListView.as_view(), name='get-all-payment-providers'),
    path('payment/', PaymentListView.as_view(), name='get-all-user-payments'),
    path('payment/create', CreatePaymentView.as_view(), name='create-payment'),
    path('payment/<int:id>', PaymentDetailAPIView.as_view(), name='payment'),
    path('cart/', CartItemListView.as_view(), name='get-all-user-cart-items'),
    path('cart/add-to-cart', AddToCartView.as_view(), name='add-to-cart'),
    path('cart/<int:id>', CartItemDetailAPIView.as_view(), name='cart'),
    path('cart/<int:id>/change-qty', ChangeQtyCartItemAPIView.as_view(), name='change-qty'),
    path('favorite/', FavoriteItemListView.as_view(), name='get-all-user-favorite-items'),
    path('favorite/add-to-favorite', AddItemToFavoriteView.as_view(), name='add-to-favorite'),
    path('favorite/<int:id>', DeleteFavoriteItemView.as_view(), name='delete-favorite'),
    path('voucher/', VoucherView.as_view(), name='get-all-vouchers'),
    path('voucher/create', CreateVoucherView.as_view(), name='create-voucher'),
    path('voucher/<int:id>', VoucherDetailAPIView.as_view(), name='voucher'),
    path('voucher/get-from-code', GetVoucherFromCodeView.as_view(), name='get-voucher-from-code'),
]

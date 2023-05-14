from rest_framework import generics, status
from .serializers import ProductSerializer, CreateProductSerializer
from .models import Product
from rest_framework.views import APIView
from rest_framework.response import Response


class ProductView(generics.ListAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer


class CreateProductView(APIView):
    serializer_class = CreateProductSerializer

    def post(self, request, format=None):
        product = Product()

        if not self.request.session.exists(self.request.session.session_key):
            self.request.session.create()

        serializer = self.serializer_class(data=request.data)
        if serializer.is_valid():
            name, desc, price = serializer.data.get('name'), serializer.data.get('desc'), serializer.data.get('price')
            product = Product(name=name, desc=desc, price=price)
            product.save()

        if product is not None:
            return Response(ProductSerializer(product).data, status=status.HTTP_201_CREATED)

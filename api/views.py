from rest_framework import generics, status
from .serializers import ProductSerializer, CreateProductSerializer
from .models import Product
from rest_framework.views import APIView
from rest_framework.response import Response


class ProductView(generics.ListAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer


# class GetProduct(APIView):
#     serializer_class = ProductSerializer
#
#     def get(self, request, product_id, format=None):
#         if product_id is not None:
#             product = Product.objects.filter(id=product_id)
#             if len(product) > 0:
#                 data = ProductSerializer(product[0]).data
#                 return Response(data, status=status.HTTP_200_OK)
#             return Response({'Product Not Found': 'Invalid Product Id'}, status=status.HTTP_404_NOT_FOUND)
#
#         return Response({'Bad Request': 'Id Parameter Not Found'}, status=status.HTTP_400_BAD_REQUEST)


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


class ProductDetailAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ProductSerializer
    queryset = Product.objects.all()

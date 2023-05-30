from django.contrib.auth import authenticate
from django.shortcuts import render
from rest_framework.generics import GenericAPIView, UpdateAPIView
from rest_framework import response, status, permissions

from api.serializers import UserSerializer, ViewUserSerializer
from authentication.models import User
from authentication.serializers import RegisterSerializer, LoginSerializer, ChangePasswordSerializer


# Create your views here.
# class AuthUserAPIView(GenericAPIView):
#     permission_classes = (permissions.IsAuthenticated,)
#
#     def get(self, request):
#         user = request.user
#         serializer = ViewUserSerializer(user)
#         return response.Response({'user': serializer.data})


class RegisterAPIView(GenericAPIView):
    authentication_classes = []

    serializer_class = RegisterSerializer

    def post(self, request):
        serializer = self.serializer_class(data=request.data)

        if serializer.is_valid():
            serializer.save()
            return response.Response(serializer.data, status=status.HTTP_201_CREATED)

        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ChangePasswordAPIView(GenericAPIView):
    permission_classes = [permissions.IsAuthenticated, ]
    serializer_class = ChangePasswordSerializer

    def put(self, request, **kwargs):
        instance = User.objects.get(email=request.user.email)
        serializer = self.serializer_class(instance, data=request.data, context={'request': request})

        if serializer.is_valid():
            serializer.save()
            return response.Response('Success', status=status.HTTP_200_OK)

        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LoginAPIView(GenericAPIView):
    authentication_classes = []

    serializer_class = LoginSerializer

    def post(self, request):
        email = request.data.get('email', None)
        password = request.data.get('password', None)

        user = authenticate(username=email, password=password)

        if user:
            serializer = self.serializer_class(user)

            return response.Response(serializer.data, status=status.HTTP_200_OK)
        return response.Response({'message': "Invalid credentials"}, status=status.HTTP_401_UNAUTHORIZED)

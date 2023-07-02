from django.contrib.auth import authenticate
from django.shortcuts import render
from rest_framework.generics import GenericAPIView, UpdateAPIView
from rest_framework import response, status, permissions

from api.serializers import UserSerializer, ViewUserSerializer
from authentication.models import User
from authentication.serializers import RegisterSerializer, LoginSerializer, ChangePasswordSerializer
from helpers.mixins import RecombeeUserMixin, RecombeeNetworkError


# Create your views here.
class RegisterAPIView(GenericAPIView, RecombeeUserMixin):
    """
    API view để đăng ký người dùng.

    Thuộc tính:
        authentication_classes: Danh sách các lớp xác thực được sử dụng cho view này.
        serializer_class: Lớp Serializer cho việc đăng ký người dùng.

    Phương thức:
        post(self, request):
            Xử lý yêu cầu POST để đăng ký người dùng.
            Input:
                request (HttpRequest): Đối tượng yêu cầu HTTP.

            Output:
                Response: Đối tượng phản hồi HTTP với dữ liệu người dùng.

    """

    authentication_classes = []

    serializer_class = RegisterSerializer

    def post(self, request):
        serializer = self.serializer_class(data=request.data)

        if serializer.is_valid():
            serializer.save()
            if self.set_recombee_user(serializer.instance, True) == 1:

                return response.Response(serializer.data, status=status.HTTP_201_CREATED)
            else:
                serializer.instance.delete()
                return RecombeeNetworkError.recombee_network_error()

        return response.Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ChangePasswordAPIView(GenericAPIView):
    """
    API view để thay đổi mật khẩu người dùng.

    Thuộc tính:
        permission_classes: Danh sách các lớp quyền truy cập được sử dụng cho view này. [permissions.IsAuthenticated, ]
        serializer_class: Lớp Serializer cho việc thay đổi mật khẩu người dùng.

    Phương thức:
        put(self, request, **kwargs):
            Xử lý yêu cầu PUT để thay đổi mật khẩu người dùng.
            Input:
                request (HttpRequest): Đối tượng yêu cầu HTTP.
                **kwargs: Các đối số khác

            Output:
                Response: Đối tượng phản hồi HTTP với thông báo thành công hoặc lỗi.

    """

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
    """
    API view để đăng nhập người dùng.

    Thuộc tính:
        authentication_classes: Danh sách các lớp xác thực được sử dụng cho view này (rỗng, cho phép bất cứ ai cũng có thể sử dụng).
        serializer_class: Lớp Serializer cho việc đăng nhập người dùng.

    Phương thức:
        post(self, request):
            Xử lý yêu cầu POST để đăng nhập người dùng.

            Input:
                request (HttpRequest): Đối tượng yêu cầu HTTP.

            Output:
                Response: Đối tượng phản hồi HTTP với dữ liệu người dùng hoặc thông báo lỗi.

    """
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

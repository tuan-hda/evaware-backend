import jwt
from rest_framework.authentication import get_authorization_header, BaseAuthentication
from authentication.models import User

from rest_framework import exceptions
import jwt

from django.conf import settings


class JWTAuthentication(BaseAuthentication):
    """
    Lớp JWTAuthentication thực hiện xác thực người dùng bằng JWT token. Đây là lớp authentication mặc định được thiết lập trong setting.py

    Phương thức:
        authenticate(request): Thực hiện quá trình xác thực người dùng dựa trên JWT token.
        Input:
            request (HttpRequest): Đối tượng HttpRequest chứa yêu cầu từ client.

        Output:
            tuple: Thông tin người dùng được xác thực và JWT token.

        Raises:
            AuthenticationFailed: Nếu quá trình xác thực không thành công.

    Note:
        - Yêu cầu JWT đã được cài đặt và SECRET_KEY đã được cấu hình trong settings.py.
        - Yêu cầu trường email được sử dụng làm thông tin xác thực cho người dùng.
    """

    def authenticate(self, request):

        auth_header = get_authorization_header(request)
        auth_data = auth_header.decode('utf-8')
        auth_token = auth_data.split(' ')

        if len(auth_token) != 2:
            raise exceptions.AuthenticationFailed('Token not valid')

        token = auth_token[1]

        try:
            payload = jwt.decode(
                token, settings.SECRET_KEY, algorithms="HS256")

            email = payload['email']

            user = User.objects.get(email=email)
            return user, token

        except jwt.ExpiredSignatureError as ex:
            raise exceptions.AuthenticationFailed(
                'Token is expired, login again')

        except jwt.DecodeError as ex:
            raise exceptions.AuthenticationFailed(
                'Token is invalid')

        except User.DoesNotExist as no_user:
            raise exceptions.AuthenticationFailed(
                'No such user')

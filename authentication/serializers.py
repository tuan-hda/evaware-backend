from rest_framework import serializers

from authentication.models import User


class ChangePasswordSerializer(serializers.ModelSerializer):
    """
    Serializer để thay đổi mật khẩu của người dùng.

    Thuộc tính:
        password (str): Mật khẩu mới cho người dùng.
        old_password (str): Mật khẩu hiện tại của người dùng.

    Phương thức:
        validate(self, attrs):
            Xác thực dữ liệu của serializer.
            Input:
                attrs (dict): Dữ liệu đầu vào.

            Output:
                dict: Dữ liệu đã được xác thực.


        update(self, instance, validated_data):
            Cập nhật mật khẩu của người dùng.
            Input:
                instance: Đối tượng người dùng.
                validated_data (dict): Dữ liệu đã được xác thực.

            Output:
                Đối tượng người dùng đã được thay đổi mật khẩu.

    Lớp Meta:
        model: User
        fields: ('old_password', 'password',)

    """

    password = serializers.CharField(
        max_length=128, min_length=6, write_only=True)
    old_password = serializers.CharField(max_length=128, min_length=6, write_only=True)

    def validate(self, attrs):
        attrs = super().validate(attrs)
        user = self.context['request'].user
        if not user.check_password(attrs['old_password']):
            raise serializers.ValidationError("Wrong old password!")

        return attrs

    def update(self, instance, validated_data):
        instance.set_password(validated_data['password'])
        instance.save()

        return instance

    class Meta:
        model = User
        fields = ('old_password', 'password',)


class RegisterSerializer(serializers.ModelSerializer):
    """
    Serializer cho việc đăng ký người dùng mới.

    Thuộc tính:
        password (str): Mật khẩu cho người dùng.

    Phương thức:
        create(self, validated_data):
            Tạo người dùng mới với dữ liệu đã xác thực.

            Input:
                validated_data (dict): Dữ liệu đã xác thực để tạo người dùng.

            Output:
                User: Đối tượng người dùng đã được tạo.

    Lớp Meta:
        model: User
        fields: ('email', 'password',)
    """
    password = serializers.CharField(
        max_length=128, min_length=6, write_only=True)

    class Meta:
        model = User
        fields = ('email', 'password',)

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class LoginSerializer(serializers.ModelSerializer):
    """
    Serializer cho việc đăng nhập người dùng.

    Thuộc tính:
        password (str): Mật khẩu cho người dùng.

    Lớp Meta:
        model: User
        fields: ('email', 'password', 'token')
        read_only_fields: ['token']. Token được đính kèm thông qua header Authorization

    """
    password = serializers.CharField(
        max_length=128, min_length=6, write_only=True)

    class Meta:
        model = User
        fields = ('email', 'password', 'token', 'is_superuser', 'is_staff')

        read_only_fields = ['token', 'is_superuser', 'is_staff']

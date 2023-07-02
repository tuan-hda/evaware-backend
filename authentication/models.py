from datetime import datetime, timedelta

from django.contrib.auth.hashers import make_password
from django.contrib.auth.validators import UnicodeUsernameValidator
from django.db import models
from django.utils import timezone

from helpers.models import TrackingModel
from django.contrib.auth.models import (PermissionsMixin, BaseUserManager, AbstractBaseUser, UserManager)
from django.apps import apps
from django.utils.translation import gettext_lazy as _
import jwt
from django.conf import settings


# Create your models here.
class MyUserManager(UserManager):
    def _create_user(self, email, password, **extra_fields):
        """
        Create and save a user with the given email, and password.
        """
        username = None

        if not email:
            raise ValueError("The given email must be set")

        email = self.normalize_email(email)
        # Lookup the real model class from the global app registry so this
        # manager method can be used in migrations. This is fine because
        # managers are by definition working on the real model.
        GlobalUserModel = apps.get_model(
            self.model._meta.app_label, self.model._meta.object_name
        )
        user = self.model(email=email, **extra_fields)
        user.password = make_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        return self._create_user(email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin, TrackingModel):
    """
    Lớp User mở rộng từ AbstractBaseUser và PermissionsMixin, đại diện cho người dùng trong hệ thống.

    Thuộc tính:
        email (EmailField): Email của người dùng (độc nhất, không được để trống).
        is_staff (BooleanField): Trạng thái nhân viên, xác định người dùng có thể đăng nhập vào trang quản trị hay không (mặc định là False).
        is_active (BooleanField): Trạng thái hoạt động, xác định xem người dùng có được coi là hoạt động hay không (mặc định là True).
        date_joined (DateTimeField): Ngày tham gia hệ thống (mặc định là ngày và giờ hiện tại).
        email_verified (BooleanField): Trạng thái xác minh email, xác định xem email của người dùng đã được xác minh hay chưa (mặc định là False).
        dob (DateField): Ngày sinh của người dùng
        full_name (TextField): Họ và tên đầy đủ của người dùng
        phone (CharField): Số điện thoại của người dùng (độ dài tối đa 15).
        gender (CharField): Giới tính của người dùng (độ dài tối đa 15, mặc định là 'Male').
        avatar (TextField): Ảnh đại diện của người dùng
        objects (MyUserManager): Đối tượng quản lý người dùng.

    Property:
        token (str): Token JWT của người dùng.

    Note:
        - Yêu cầu cài đặt SECRET_KEY trong settings.py.
    """
    email = models.EmailField(_("email address"), blank=False, unique=True, error_messages={
        'unique': _("A user with that email already exists."),
    }, )
    is_staff = models.BooleanField(
        _("staff status"),
        default=False,
        help_text=_("Designates whether the user can log into this admin site."),
    )
    is_active = models.BooleanField(
        _("active"),
        default=True,
        help_text=_(
            "Designates whether this user should be treated as active. "
            "Unselect this instead of deleting accounts."
        ),
    )
    date_joined = models.DateTimeField(_("date joined"), default=timezone.now)
    email_verified = models.BooleanField(
        _("email_verified"),
        default=False,
        help_text=_(
            "Designates whether this user's email is verified"
        ),
    )
    dob = models.DateField(blank=True, null=True)
    full_name = models.TextField(blank=True, null=True)
    phone = models.CharField(max_length=15, null=True)
    gender = models.CharField(max_length=15, null=True, default='Male')
    avatar = models.TextField(default='')
    points = models.IntegerField(default='0')
    objects = MyUserManager()

    EMAIL_FIELD = "email"
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    @property
    def token(self):
        token = jwt.encode(
            {
                "email": self.email,
                "exp": datetime.utcnow() + timedelta(days=30),
                "is_staff": self.is_staff,
                "is_superuser": self.is_superuser,
            },
            settings.SECRET_KEY,
            algorithm="HS256",
        )

        return token

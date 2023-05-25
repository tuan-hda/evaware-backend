from django.contrib.auth.models import (PermissionsMixin, BaseUserManager, AbstractBaseUser)
from django.db import models

from helpers.models import TrackingModel


# Create your models here.

class User(AbstractBaseUser, PermissionsMixin, TrackingModel):
    pass

from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.db import models

class CustomUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)   # hashes the password
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        return self.create_user(email, password, **extra_fields)


class CustomUser(AbstractBaseUser, PermissionsMixin):
    email       = models.EmailField(unique=True)
    name        = models.CharField(max_length=150)
    profile_pic = models.ImageField(upload_to='profile_pics/', null=True, blank=True)
    location    = models.CharField(max_length=100, null=True, blank=True)
    is_active   = models.BooleanField(default=True)
    is_staff    = models.BooleanField(default=False)
    created_at  = models.DateTimeField(auto_now_add=True)

    objects = CustomUserManager()

    USERNAME_FIELD  = 'email'    # login with email
    REQUIRED_FIELDS = ['name']   # asked when creating superuser

    def __str__(self):
        return self.email
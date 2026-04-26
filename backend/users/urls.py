from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import RegisterView, ProfileView

urlpatterns = [
    path('register/', RegisterView.as_view()),
    path('login/',    TokenObtainPairView.as_view()),   # returns access + refresh token
    path('token/refresh/', TokenRefreshView.as_view()), # get new access token
    path('profile/',  ProfileView.as_view()),
]
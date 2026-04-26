from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()  # always use this, not CustomUser directly

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ['email', 'name', 'password']

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'name', 'profile_pic', 'location', 'created_at']
        read_only_fields = ['id', 'email', 'created_at']
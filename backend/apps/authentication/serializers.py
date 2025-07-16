from rest_framework import serializers
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from .models import CustomUser, OTPVerification, WalletTransaction
import re


class UserRegistrationSerializer(serializers.ModelSerializer):
    """
    Serializer for user registration with phone number and OTP
    """
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)
    otp_code = serializers.CharField(write_only=True, max_length=6)
    
    class Meta:
        model = CustomUser
        fields = [
            'phone_number', 'username', 'email', 'first_name', 'last_name',
            'password', 'password_confirm', 'otp_code', 'city', 'state', 'pincode'
        ]
    
    def validate_phone_number(self, value):
        """Validate Indian phone number format"""
        pattern = r'^[6-9]\d{9}$'
        if not re.match(pattern, value):
            raise serializers.ValidationError("Enter a valid Indian phone number")
        return value
    
    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError("Passwords don't match")
        
        # Verify OTP
        try:
            otp_obj = OTPVerification.objects.get(
                phone_number=attrs['phone_number'],
                purpose='registration',
                is_verified=False
            )
            is_valid, message = otp_obj.verify(attrs['otp_code'])
            if not is_valid:
                raise serializers.ValidationError(f"OTP verification failed: {message}")
        except OTPVerification.DoesNotExist:
            raise serializers.ValidationError("No valid OTP found for this phone number")
        
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('password_confirm')
        validated_data.pop('otp_code')
        
        user = CustomUser.objects.create_user(**validated_data)
        return user


class UserLoginSerializer(serializers.Serializer):
    """
    Serializer for user login
    """
    phone_number = serializers.CharField()
    password = serializers.CharField(write_only=True)
    
    def validate(self, attrs):
        phone_number = attrs.get('phone_number')
        password = attrs.get('password')
        
        if phone_number and password:
            user = authenticate(username=phone_number, password=password)
            if not user:
                raise serializers.ValidationError("Invalid credentials")
            if not user.is_active:
                raise serializers.ValidationError("User account is disabled")
            attrs['user'] = user
        else:
            raise serializers.ValidationError("Must include phone number and password")
        
        return attrs


class KYCVerificationSerializer(serializers.Serializer):
    """
    Serializer for Aadhaar-based KYC verification
    """
    aadhaar_number = serializers.CharField(max_length=12, min_length=12)
    otp_code = serializers.CharField(max_length=6)
    
    def validate_aadhaar_number(self, value):
        """Validate Aadhaar number format"""
        if not value.isdigit():
            raise serializers.ValidationError("Aadhaar number must contain only digits")
        
        # Luhn algorithm validation for Aadhaar
        def luhn_check(number):
            digits = [int(d) for d in number]
            checksum = 0
            reverse_digits = digits[::-1]
            
            for i, d in enumerate(reverse_digits):
                if i % 2 == 1:
                    d = d * 2
                    if d > 9:
                        d = d // 10 + d % 10
                checksum += d
            
            return checksum % 10 == 0
        
        if not luhn_check(value):
            raise serializers.ValidationError("Invalid Aadhaar number")
        
        return value


class UserProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for user profile information
    """
    wallet_balance = serializers.DecimalField(max_digits=10, decimal_places=2, read_only=True)
    
    class Meta:
        model = CustomUser
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name',
            'phone_number', 'city', 'state', 'pincode', 'role',
            'kyc_status', 'aadhaar_verified', 'wallet_balance',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'phone_number', 'role', 'kyc_status', 'aadhaar_verified', 'created_at', 'updated_at']


class WalletTransactionSerializer(serializers.ModelSerializer):
    """
    Serializer for wallet transactions
    """
    class Meta:
        model = WalletTransaction
        fields = ['id', 'amount', 'transaction_type', 'description', 'reference_id', 'balance_after', 'created_at']
        read_only_fields = ['id', 'created_at']


class OTPRequestSerializer(serializers.Serializer):
    """
    Serializer for OTP request
    """
    phone_number = serializers.CharField(max_length=15)
    purpose = serializers.ChoiceField(choices=[
        ('registration', 'Registration'),
        ('login', 'Login'),
        ('kyc', 'KYC Verification'),
        ('password_reset', 'Password Reset'),
    ])
    
    def validate_phone_number(self, value):
        """Validate Indian phone number format"""
        pattern = r'^[6-9]\d{9}$'
        if not re.match(pattern, value):
            raise serializers.ValidationError("Enter a valid Indian phone number")
        return value


class PasswordResetSerializer(serializers.Serializer):
    """
    Serializer for password reset
    """
    phone_number = serializers.CharField()
    otp_code = serializers.CharField(max_length=6)
    new_password = serializers.CharField(validators=[validate_password])
    confirm_password = serializers.CharField()
    
    def validate(self, attrs):
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError("Passwords don't match")
        
        # Verify OTP
        try:
            otp_obj = OTPVerification.objects.get(
                phone_number=attrs['phone_number'],
                purpose='password_reset',
                is_verified=False
            )
            is_valid, message = otp_obj.verify(attrs['otp_code'])
            if not is_valid:
                raise serializers.ValidationError(f"OTP verification failed: {message}")
        except OTPVerification.DoesNotExist:
            raise serializers.ValidationError("No valid OTP found for this phone number")
        
        return attrs

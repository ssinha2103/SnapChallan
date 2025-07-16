from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import login, logout
from django.utils import timezone
from django.conf import settings
from .models import CustomUser, OTPVerification, WalletTransaction, AuditLog
from .serializers import (
    UserRegistrationSerializer, UserLoginSerializer, KYCVerificationSerializer,
    UserProfileSerializer, WalletTransactionSerializer, OTPRequestSerializer,
    PasswordResetSerializer
)
from .utils import send_otp, verify_aadhaar_with_uidai, get_client_ip
import random
import string
from datetime import timedelta


class OTPRequestView(APIView):
    """
    Send OTP for various purposes (registration, login, KYC, password reset)
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        serializer = OTPRequestSerializer(data=request.data)
        if serializer.is_valid():
            phone_number = serializer.validated_data['phone_number']
            purpose = serializer.validated_data['purpose']
            
            # Generate 6-digit OTP
            otp_code = ''.join(random.choices(string.digits, k=6))
            
            # Create OTP record
            expires_at = timezone.now() + timedelta(minutes=10)
            otp_obj, created = OTPVerification.objects.get_or_create(
                phone_number=phone_number,
                purpose=purpose,
                is_verified=False,
                defaults={
                    'otp_code': otp_code,
                    'expires_at': expires_at,
                    'attempts': 0
                }
            )
            
            if not created:
                # Update existing OTP
                otp_obj.otp_code = otp_code
                otp_obj.expires_at = expires_at
                otp_obj.attempts = 0
                otp_obj.save()
            
            # Send OTP via SMS
            success = send_otp(phone_number, otp_code, purpose)
            
            if success:
                return Response({
                    'message': 'OTP sent successfully',
                    'expires_in': 600  # 10 minutes
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'error': 'Failed to send OTP'
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class UserRegistrationView(APIView):
    """
    Register new user with phone number and OTP verification
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        serializer = UserRegistrationSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            
            # Create audit log
            AuditLog.objects.create(
                user=user,
                action='user_registration',
                resource_type='user',
                resource_id=str(user.id),
                ip_address=get_client_ip(request),
                user_agent=request.META.get('HTTP_USER_AGENT', ''),
                details={'registration_method': 'phone_otp'}
            )
            
            # Generate JWT tokens
            refresh = RefreshToken.for_user(user)
            
            return Response({
                'message': 'User registered successfully',
                'user': UserProfileSerializer(user).data,
                'tokens': {
                    'refresh': str(refresh),
                    'access': str(refresh.access_token),
                }
            }, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class UserLoginView(APIView):
    """
    User login with phone number and password
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        serializer = UserLoginSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.validated_data['user']
            
            # Update last login info
            user.last_login = timezone.now()
            user.last_login_ip = get_client_ip(request)
            user.save()
            
            # Create audit log
            AuditLog.objects.create(
                user=user,
                action='user_login',
                resource_type='user',
                resource_id=str(user.id),
                ip_address=get_client_ip(request),
                user_agent=request.META.get('HTTP_USER_AGENT', ''),
                details={'login_method': 'password'}
            )
            
            # Generate JWT tokens
            refresh = RefreshToken.for_user(user)
            
            return Response({
                'message': 'Login successful',
                'user': UserProfileSerializer(user).data,
                'tokens': {
                    'refresh': str(refresh),
                    'access': str(refresh.access_token),
                }
            }, status=status.HTTP_200_OK)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class UserLogoutView(APIView):
    """
    User logout and token blacklisting
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        try:
            refresh_token = request.data["refresh_token"]
            token = RefreshToken(refresh_token)
            token.blacklist()
            
            # Create audit log
            AuditLog.objects.create(
                user=request.user,
                action='user_logout',
                resource_type='user',
                resource_id=str(request.user.id),
                ip_address=get_client_ip(request),
                user_agent=request.META.get('HTTP_USER_AGENT', ''),
                details={}
            )
            
            return Response({
                'message': 'Logout successful'
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({
                'error': 'Invalid token'
            }, status=status.HTTP_400_BAD_REQUEST)


class KYCVerificationView(APIView):
    """
    Aadhaar-based eKYC verification
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        if request.user.aadhaar_verified:
            return Response({
                'error': 'KYC already completed'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        serializer = KYCVerificationSerializer(data=request.data)
        if serializer.is_valid():
            aadhaar_number = serializer.validated_data['aadhaar_number']
            otp_code = serializer.validated_data['otp_code']
            
            # Verify with UIDAI
            verification_result = verify_aadhaar_with_uidai(aadhaar_number, otp_code)
            
            if verification_result.get('success'):
                # Hash and store Aadhaar
                request.user.hash_aadhaar(aadhaar_number)
                request.user.complete_kyc()
                
                # Create audit log
                AuditLog.objects.create(
                    user=request.user,
                    action='kyc_verification',
                    resource_type='user',
                    resource_id=str(request.user.id),
                    ip_address=get_client_ip(request),
                    user_agent=request.META.get('HTTP_USER_AGENT', ''),
                    details={'verification_method': 'aadhaar_uidai'}
                )
                
                return Response({
                    'message': 'KYC verification successful',
                    'user': UserProfileSerializer(request.user).data
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'error': 'KYC verification failed',
                    'details': verification_result.get('message', 'Unknown error')
                }, status=status.HTTP_400_BAD_REQUEST)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class UserProfileView(APIView):
    """
    Get and update user profile
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        serializer = UserProfileSerializer(request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    def put(self, request):
        serializer = UserProfileSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            
            # Create audit log
            AuditLog.objects.create(
                user=request.user,
                action='profile_update',
                resource_type='user',
                resource_id=str(request.user.id),
                ip_address=get_client_ip(request),
                user_agent=request.META.get('HTTP_USER_AGENT', ''),
                details={'updated_fields': list(request.data.keys())}
            )
            
            return Response(serializer.data, status=status.HTTP_200_OK)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class WalletView(APIView):
    """
    Get wallet balance and transaction history
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        transactions = WalletTransaction.objects.filter(user=request.user)[:20]
        return Response({
            'balance': request.user.wallet_balance,
            'transactions': WalletTransactionSerializer(transactions, many=True).data
        }, status=status.HTTP_200_OK)


class PasswordResetView(APIView):
    """
    Reset password using OTP
    """
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        serializer = PasswordResetSerializer(data=request.data)
        if serializer.is_valid():
            phone_number = serializer.validated_data['phone_number']
            new_password = serializer.validated_data['new_password']
            
            try:
                user = CustomUser.objects.get(phone_number=phone_number)
                user.set_password(new_password)
                user.save()
                
                # Create audit log
                AuditLog.objects.create(
                    user=user,
                    action='password_reset',
                    resource_type='user',
                    resource_id=str(user.id),
                    ip_address=get_client_ip(request),
                    user_agent=request.META.get('HTTP_USER_AGENT', ''),
                    details={'reset_method': 'otp'}
                )
                
                return Response({
                    'message': 'Password reset successful'
                }, status=status.HTTP_200_OK)
            
            except CustomUser.DoesNotExist:
                return Response({
                    'error': 'User not found'
                }, status=status.HTTP_404_NOT_FOUND)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

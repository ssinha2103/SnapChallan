from django.urls import path
from .views import (
    OTPRequestView, UserRegistrationView, UserLoginView, UserLogoutView,
    KYCVerificationView, UserProfileView, WalletView, PasswordResetView
)

urlpatterns = [
    path('otp/request/', OTPRequestView.as_view(), name='otp_request'),
    path('register/', UserRegistrationView.as_view(), name='user_register'),
    path('login/', UserLoginView.as_view(), name='user_login'),
    path('logout/', UserLogoutView.as_view(), name='user_logout'),
    path('kyc/verify/', KYCVerificationView.as_view(), name='kyc_verify'),
    path('profile/', UserProfileView.as_view(), name='user_profile'),
    path('wallet/', WalletView.as_view(), name='user_wallet'),
    path('password/reset/', PasswordResetView.as_view(), name='password_reset'),
]

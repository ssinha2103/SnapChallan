from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone
import hashlib
import secrets


class CustomUser(AbstractUser):
    """
    Custom user model with Aadhaar-based eKYC integration
    """
    ROLE_CHOICES = [
        ('citizen', 'Citizen'),
        ('officer', 'Traffic Officer'),
        ('admin', 'Admin'),
    ]
    
    phone_number = models.CharField(max_length=15, unique=True)
    aadhaar_hash = models.CharField(max_length=64, blank=True, null=True)  # SHA-256 hashed
    aadhaar_verified = models.BooleanField(default=False)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='citizen')
    
    # eKYC related fields
    kyc_status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending'),
            ('verified', 'Verified'),
            ('rejected', 'Rejected'),
        ],
        default='pending'
    )
    kyc_completed_at = models.DateTimeField(blank=True, null=True)
    
    # Location and profile
    city = models.CharField(max_length=100, blank=True)
    state = models.CharField(max_length=100, blank=True)
    pincode = models.CharField(max_length=10, blank=True)
    
    # Wallet
    wallet_balance = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    
    # Security
    otp_secret = models.CharField(max_length=64, blank=True)
    otp_verified_at = models.DateTimeField(blank=True, null=True)
    last_login_ip = models.GenericIPAddressField(blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    USERNAME_FIELD = 'phone_number'
    REQUIRED_FIELDS = ['username', 'email']
    
    class Meta:
        db_table = 'auth_custom_user'
        indexes = [
            models.Index(fields=['phone_number']),
            models.Index(fields=['aadhaar_hash']),
            models.Index(fields=['role']),
        ]
    
    def hash_aadhaar(self, aadhaar_number):
        """Hash Aadhaar number with salt for secure storage"""
        salt = secrets.token_hex(16)
        aadhaar_with_salt = f"{aadhaar_number}{salt}"
        hashed = hashlib.sha256(aadhaar_with_salt.encode()).hexdigest()
        self.aadhaar_hash = f"{salt}:{hashed}"
        return self.aadhaar_hash
    
    def verify_aadhaar(self, aadhaar_number):
        """Verify Aadhaar number against stored hash"""
        if not self.aadhaar_hash:
            return False
        
        try:
            salt, stored_hash = self.aadhaar_hash.split(':')
            aadhaar_with_salt = f"{aadhaar_number}{salt}"
            computed_hash = hashlib.sha256(aadhaar_with_salt.encode()).hexdigest()
            return computed_hash == stored_hash
        except ValueError:
            return False
    
    def complete_kyc(self):
        """Mark KYC as completed"""
        self.kyc_status = 'verified'
        self.kyc_completed_at = timezone.now()
        self.aadhaar_verified = True
        self.save()
    
    def add_to_wallet(self, amount, description=""):
        """Add money to user wallet"""
        self.wallet_balance += amount
        self.save()
        
        # Create transaction record
        WalletTransaction.objects.create(
            user=self,
            amount=amount,
            transaction_type='credit',
            description=description,
            balance_after=self.wallet_balance
        )
    
    def deduct_from_wallet(self, amount, description=""):
        """Deduct money from user wallet"""
        if self.wallet_balance >= amount:
            self.wallet_balance -= amount
            self.save()
            
            # Create transaction record
            WalletTransaction.objects.create(
                user=self,
                amount=amount,
                transaction_type='debit',
                description=description,
                balance_after=self.wallet_balance
            )
            return True
        return False


class OTPVerification(models.Model):
    """
    Store OTP verification attempts
    """
    phone_number = models.CharField(max_length=15)
    otp_code = models.CharField(max_length=6)
    purpose = models.CharField(
        max_length=20,
        choices=[
            ('registration', 'Registration'),
            ('login', 'Login'),
            ('kyc', 'KYC Verification'),
            ('password_reset', 'Password Reset'),
        ]
    )
    is_verified = models.BooleanField(default=False)
    attempts = models.PositiveIntegerField(default=0)
    max_attempts = models.PositiveIntegerField(default=3)
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    verified_at = models.DateTimeField(blank=True, null=True)
    
    class Meta:
        db_table = 'auth_otp_verification'
        indexes = [
            models.Index(fields=['phone_number', 'purpose']),
            models.Index(fields=['expires_at']),
        ]
    
    def is_expired(self):
        return timezone.now() > self.expires_at
    
    def verify(self, otp_code):
        if self.is_expired():
            return False, "OTP has expired"
        
        if self.attempts >= self.max_attempts:
            return False, "Maximum attempts exceeded"
        
        self.attempts += 1
        self.save()
        
        if self.otp_code == otp_code:
            self.is_verified = True
            self.verified_at = timezone.now()
            self.save()
            return True, "OTP verified successfully"
        
        return False, "Invalid OTP"


class WalletTransaction(models.Model):
    """
    Track all wallet transactions
    """
    TRANSACTION_TYPES = [
        ('credit', 'Credit'),
        ('debit', 'Debit'),
    ]
    
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='wallet_transactions')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    transaction_type = models.CharField(max_length=10, choices=TRANSACTION_TYPES)
    description = models.TextField(blank=True)
    reference_id = models.CharField(max_length=100, blank=True)  # UPI transaction ID, etc.
    balance_after = models.DecimalField(max_digits=10, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'auth_wallet_transaction'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['transaction_type']),
        ]


class AuditLog(models.Model):
    """
    Immutable audit trail for all user actions
    """
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='audit_logs')
    action = models.CharField(max_length=100)
    resource_type = models.CharField(max_length=50)  # violation, payment, etc.
    resource_id = models.CharField(max_length=100, blank=True)
    ip_address = models.GenericIPAddressField()
    user_agent = models.TextField(blank=True)
    details = models.JSONField(default=dict)
    timestamp = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'auth_audit_log'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['user', '-timestamp']),
            models.Index(fields=['action']),
            models.Index(fields=['resource_type']),
        ]

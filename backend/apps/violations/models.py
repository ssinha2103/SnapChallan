from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone
import uuid

User = get_user_model()


class ViolationType(models.Model):
    """
    Types of traffic violations
    """
    name = models.CharField(max_length=100, unique=True)
    code = models.CharField(max_length=20, unique=True)
    description = models.TextField()
    fine_amount = models.DecimalField(max_digits=10, decimal_places=2)
    
    # AI detection related
    ai_detectable = models.BooleanField(default=False)
    confidence_threshold = models.FloatField(default=0.7)
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'violations_violation_type'
        ordering = ['name']
    
    def __str__(self):
        return f"{self.code} - {self.name}"


class Violation(models.Model):
    """
    Traffic violation reports submitted by citizens
    """
    STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('under_review', 'Under Review'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('challan_issued', 'Challan Issued'),
        ('payment_received', 'Payment Received'),
        ('closed', 'Closed'),
    ]
    
    # Unique identifier
    violation_id = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    
    # Reporter information
    reporter = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reported_violations')
    
    # Violation details
    violation_type = models.ForeignKey(ViolationType, on_delete=models.CASCADE)
    description = models.TextField()
    
    # Location data
    latitude = models.FloatField()
    longitude = models.FloatField()
    location_address = models.TextField()
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=10)
    
    # Vehicle information (extracted or manual)
    vehicle_number = models.CharField(max_length=20, blank=True)
    vehicle_type = models.CharField(max_length=50, blank=True)
    vehicle_color = models.CharField(max_length=30, blank=True)
    
    # Timing
    occurred_at = models.DateTimeField()
    reported_at = models.DateTimeField(auto_now_add=True)
    
    # Status and review
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    reviewed_by = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='reviewed_violations'
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    review_notes = models.TextField(blank=True)
    
    # AI analysis results
    ai_processed = models.BooleanField(default=False)
    ai_confidence_score = models.FloatField(null=True, blank=True)
    ai_detected_objects = models.JSONField(default=dict)
    ai_extracted_data = models.JSONField(default=dict)
    
    # Reward system
    reward_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    reward_paid = models.BooleanField(default=False)
    reward_paid_at = models.DateTimeField(null=True, blank=True)
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'violations_violation'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['reporter', '-created_at']),
            models.Index(fields=['status']),
            models.Index(fields=['violation_type']),
            models.Index(fields=['city', 'state']),
            models.Index(fields=['occurred_at']),
        ]
    
    def __str__(self):
        return f"Violation {self.violation_id} - {self.violation_type.name}"
    
    def approve(self, reviewer, notes=""):
        """Approve violation and calculate reward"""
        self.status = 'approved'
        self.reviewed_by = reviewer
        self.reviewed_at = timezone.now()
        self.review_notes = notes
        
        # Calculate 40% reward
        self.reward_amount = self.violation_type.fine_amount * 0.4
        self.save()
    
    def reject(self, reviewer, notes=""):
        """Reject violation"""
        self.status = 'rejected'
        self.reviewed_by = reviewer
        self.reviewed_at = timezone.now()
        self.review_notes = notes
        self.save()
    
    def issue_challan(self):
        """Mark as challan issued"""
        self.status = 'challan_issued'
        self.save()
    
    def mark_payment_received(self):
        """Mark payment as received and pay reward"""
        self.status = 'payment_received'
        
        if not self.reward_paid and self.reward_amount > 0:
            # Add reward to reporter's wallet
            self.reporter.add_to_wallet(
                self.reward_amount,
                f"Reward for violation {self.violation_id}"
            )
            self.reward_paid = True
            self.reward_paid_at = timezone.now()
        
        self.save()


class ViolationMedia(models.Model):
    """
    Media files (photos/videos) associated with violations
    """
    MEDIA_TYPES = [
        ('image', 'Image'),
        ('video', 'Video'),
    ]
    
    violation = models.ForeignKey(Violation, on_delete=models.CASCADE, related_name='media_files')
    media_type = models.CharField(max_length=10, choices=MEDIA_TYPES)
    
    # GridFS storage
    gridfs_file_id = models.CharField(max_length=100)
    filename = models.CharField(max_length=255)
    file_size = models.PositiveIntegerField()
    content_type = models.CharField(max_length=100)
    
    # EXIF data
    gps_latitude = models.FloatField(null=True, blank=True)
    gps_longitude = models.FloatField(null=True, blank=True)
    timestamp = models.DateTimeField(null=True, blank=True)
    camera_make = models.CharField(max_length=100, blank=True)
    camera_model = models.CharField(max_length=100, blank=True)
    
    # Processing status
    processed = models.BooleanField(default=False)
    processing_error = models.TextField(blank=True)
    
    uploaded_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'violations_violation_media'
        ordering = ['violation', 'uploaded_at']
        indexes = [
            models.Index(fields=['violation']),
            models.Index(fields=['media_type']),
            models.Index(fields=['processed']),
        ]
    
    def __str__(self):
        return f"Media for {self.violation.violation_id} - {self.filename}"


class ViolationComment(models.Model):
    """
    Comments and notes on violations (by officers)
    """
    violation = models.ForeignKey(Violation, on_delete=models.CASCADE, related_name='comments')
    author = models.ForeignKey(User, on_delete=models.CASCADE)
    comment = models.TextField()
    is_internal = models.BooleanField(default=True)  # Internal officer notes vs public comments
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'violations_violation_comment'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['violation', '-created_at']),
            models.Index(fields=['author']),
        ]
    
    def __str__(self):
        return f"Comment on {self.violation.violation_id} by {self.author.username}"


class Challan(models.Model):
    """
    Official challan records
    """
    CHALLAN_STATUS = [
        ('pending', 'Pending'),
        ('issued', 'Issued'),
        ('paid', 'Paid'),
        ('overdue', 'Overdue'),
        ('cancelled', 'Cancelled'),
    ]
    
    violation = models.OneToOneField(Violation, on_delete=models.CASCADE, related_name='challan')
    challan_number = models.CharField(max_length=50, unique=True)
    
    # Vehicle owner details (from MoRTH API)
    owner_name = models.CharField(max_length=200)
    owner_address = models.TextField()
    owner_phone = models.CharField(max_length=15, blank=True)
    
    # Challan details
    fine_amount = models.DecimalField(max_digits=10, decimal_places=2)
    penalty_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    
    # Status and timing
    status = models.CharField(max_length=20, choices=CHALLAN_STATUS, default='pending')
    issued_at = models.DateTimeField(null=True, blank=True)
    due_date = models.DateTimeField()
    paid_at = models.DateTimeField(null=True, blank=True)
    
    # MoRTH integration
    morth_challan_id = models.CharField(max_length=100, blank=True)
    morth_response = models.JSONField(default=dict)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'violations_challan'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['challan_number']),
            models.Index(fields=['status']),
            models.Index(fields=['due_date']),
        ]
    
    def __str__(self):
        return f"Challan {self.challan_number} - {self.violation.vehicle_number}"
    
    def mark_paid(self):
        """Mark challan as paid and trigger reward payment"""
        self.status = 'paid'
        self.paid_at = timezone.now()
        self.save()
        
        # Update violation status and pay reward
        self.violation.mark_payment_received()


class Statistics(models.Model):
    """
    Daily statistics for dashboard
    """
    date = models.DateField(unique=True)
    
    # Violation counts
    total_violations = models.PositiveIntegerField(default=0)
    pending_violations = models.PositiveIntegerField(default=0)
    approved_violations = models.PositiveIntegerField(default=0)
    rejected_violations = models.PositiveIntegerField(default=0)
    
    # Challan counts
    challans_issued = models.PositiveIntegerField(default=0)
    challans_paid = models.PositiveIntegerField(default=0)
    
    # Financial data
    total_fines_collected = models.DecimalField(max_digits=15, decimal_places=2, default=0.00)
    total_rewards_paid = models.DecimalField(max_digits=15, decimal_places=2, default=0.00)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        db_table = 'violations_statistics'
        ordering = ['-date']

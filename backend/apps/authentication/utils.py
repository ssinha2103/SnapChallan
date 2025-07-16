import requests
import random
import string
from django.conf import settings
from django.core.mail import send_mail
from typing import Dict, Any


def get_client_ip(request) -> str:
    """
    Get client IP address from request
    """
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


def send_otp(phone_number: str, otp_code: str, purpose: str) -> bool:
    """
    Send OTP via SMS using SMS gateway
    """
    try:
        # SMS API integration (example with TextLocal)
        message = f"Your SnapChallan OTP for {purpose} is: {otp_code}. Valid for 10 minutes. Do not share this OTP."
        
        # Mock SMS sending - replace with actual SMS gateway
        if settings.DEBUG:
            print(f"SMS to {phone_number}: {message}")
            return True
        
        # Example SMS API call
        sms_data = {
            'apikey': settings.SMS_API_KEY,
            'numbers': phone_number,
            'message': message,
            'sender': 'SNAPCH'
        }
        
        response = requests.post(
            settings.SMS_API_URL,
            data=sms_data,
            timeout=10
        )
        
        return response.status_code == 200
    
    except Exception as e:
        print(f"SMS sending failed: {e}")
        return False


def verify_aadhaar_with_uidai(aadhaar_number: str, otp_code: str) -> Dict[str, Any]:
    """
    Verify Aadhaar with UIDAI eKYC API
    """
    try:
        # UIDAI API integration
        if settings.DEBUG:
            # Mock verification for development
            if otp_code == "123456":
                return {
                    'success': True,
                    'message': 'Verification successful',
                    'data': {
                        'name': 'Test User',
                        'gender': 'M',
                        'dateOfBirth': '01-01-1990',
                        'address': 'Test Address'
                    }
                }
            else:
                return {
                    'success': False,
                    'message': 'Invalid OTP'
                }
        
        # Production UIDAI API call
        headers = {
            'Authorization': f'Bearer {settings.UIDAI_API_KEY}',
            'Content-Type': 'application/json'
        }
        
        payload = {
            'aadhaar_number': aadhaar_number,
            'otp': otp_code,
            'purpose': 'eKYC'
        }
        
        response = requests.post(
            f"{settings.UIDAI_API_BASE_URL}/verify",
            json=payload,
            headers=headers,
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            return {
                'success': data.get('status') == 'success',
                'message': data.get('message', ''),
                'data': data.get('data', {})
            }
        else:
            return {
                'success': False,
                'message': 'UIDAI API error'
            }
    
    except requests.RequestException as e:
        return {
            'success': False,
            'message': f'Network error: {str(e)}'
        }
    except Exception as e:
        return {
            'success': False,
            'message': f'Verification error: {str(e)}'
        }


def generate_secure_token(length: int = 32) -> str:
    """
    Generate a secure random token
    """
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))


def validate_indian_phone(phone_number: str) -> bool:
    """
    Validate Indian phone number format
    """
    import re
    pattern = r'^[6-9]\d{9}$'
    return bool(re.match(pattern, phone_number))


def mask_aadhaar(aadhaar_number: str) -> str:
    """
    Mask Aadhaar number for display (show only last 4 digits)
    """
    if len(aadhaar_number) != 12:
        return "****-****-****"
    return f"****-****-{aadhaar_number[-4:]}"


def mask_phone(phone_number: str) -> str:
    """
    Mask phone number for display
    """
    if len(phone_number) < 6:
        return "*" * len(phone_number)
    return f"******{phone_number[-4:]}"

# SnapChallan API Documentation

## Authentication Endpoints

### POST /api/auth/register/
Register a new citizen account.

**Request Body:**
```json
{
  "phone_number": "+919876543210",
  "password": "SecurePass123!",
  "first_name": "John",
  "last_name": "Doe",
  "email": "john.doe@example.com"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Registration successful. Please verify your phone number.",
  "user": {
    "id": "674a8b2d1234567890abcdef",
    "phone_number": "+919876543210",
    "first_name": "John",
    "last_name": "Doe",
    "email": "john.doe@example.com",
    "is_verified": false,
    "aadhaar_verified": false
  }
}
```

### POST /api/auth/verify-otp/
Verify phone number with OTP.

**Request Body:**
```json
{
  "phone_number": "+919876543210",
  "otp": "123456"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Phone number verified successfully",
  "tokens": {
    "access": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "refresh": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
  }
}
```

### POST /api/auth/login/
Login with phone number and password.

**Request Body:**
```json
{
  "phone_number": "+919876543210",
  "password": "SecurePass123!"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Login successful",
  "tokens": {
    "access": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "refresh": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
  },
  "user": {
    "id": "674a8b2d1234567890abcdef",
    "phone_number": "+919876543210",
    "first_name": "John",
    "last_name": "Doe",
    "role": "citizen"
  }
}
```

### POST /api/auth/refresh/
Refresh access token.

**Request Body:**
```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

**Response (200 OK):**
```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

### POST /api/auth/kyc/verify/
Verify Aadhaar details.

**Request Body:**
```json
{
  "aadhaar_number": "123456789012",
  "name": "John Doe",
  "otp": "123456"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Aadhaar verification successful",
  "verification_id": "kyc_674a8b2d1234567890abcdef"
}
```

## Violation Endpoints

### POST /api/violations/
Submit a new violation report.

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: multipart/form-data
```

**Request Body (form-data):**
```
description: "Vehicle running red light"
violation_type: "traffic_signal"
location_latitude: 28.6139
location_longitude: 77.2090
location_address: "India Gate, New Delhi"
evidence_file: <image/video file>
evidence_file_2: <optional second file>
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Violation submitted successfully",
  "violation": {
    "id": "674a8b2d1234567890abcdef",
    "violation_id": "VIO20241125001",
    "description": "Vehicle running red light",
    "violation_type": "traffic_signal",
    "status": "pending_verification",
    "location": {
      "latitude": 28.6139,
      "longitude": 77.2090,
      "address": "India Gate, New Delhi"
    },
    "evidence_files": [
      {
        "url": "/api/files/674a8b2d1234567890abcdef/",
        "filename": "evidence1.jpg",
        "type": "image"
      }
    ],
    "submitted_at": "2024-11-25T10:30:00Z",
    "ai_analysis": {
      "confidence": 0.95,
      "detected_objects": ["vehicle", "traffic_light"],
      "license_plate": "DL01AB1234"
    }
  }
}
```

### GET /api/violations/
Get user's violation reports.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `status`: Filter by status (pending_verification, verified, rejected, resolved)
- `page`: Page number (default: 1)
- `page_size`: Items per page (default: 10)

**Response (200 OK):**
```json
{
  "count": 25,
  "next": "/api/violations/?page=2",
  "previous": null,
  "results": [
    {
      "id": "674a8b2d1234567890abcdef",
      "violation_id": "VIO20241125001",
      "description": "Vehicle running red light",
      "violation_type": "traffic_signal",
      "status": "verified",
      "location": {
        "address": "India Gate, New Delhi"
      },
      "submitted_at": "2024-11-25T10:30:00Z",
      "challan_amount": 5000,
      "reward_amount": 2000
    }
  ]
}
```

### GET /api/violations/{id}/
Get detailed violation information.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "id": "674a8b2d1234567890abcdef",
  "violation_id": "VIO20241125001",
  "description": "Vehicle running red light",
  "violation_type": "traffic_signal",
  "status": "verified",
  "location": {
    "latitude": 28.6139,
    "longitude": 77.2090,
    "address": "India Gate, New Delhi"
  },
  "evidence_files": [
    {
      "url": "/api/files/674a8b2d1234567890abcdef/",
      "filename": "evidence1.jpg",
      "type": "image"
    }
  ],
  "submitted_at": "2024-11-25T10:30:00Z",
  "verified_at": "2024-11-25T14:30:00Z",
  "challan_amount": 5000,
  "reward_amount": 2000,
  "ai_analysis": {
    "confidence": 0.95,
    "detected_objects": ["vehicle", "traffic_light"],
    "license_plate": "DL01AB1234",
    "helmet_detection": {
      "riders_detected": 1,
      "helmets_detected": 0,
      "violation_confirmed": true
    }
  },
  "officer_review": {
    "officer_id": "674a8b2d1234567890abcdef",
    "comments": "Clear violation captured, challan issued",
    "reviewed_at": "2024-11-25T14:30:00Z"
  }
}
```

## Reward System

### GET /api/rewards/
Get user's reward history.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "total_earned": 15000,
  "available_balance": 12000,
  "withdrawn": 3000,
  "rewards": [
    {
      "id": "674a8b2d1234567890abcdef",
      "violation_id": "VIO20241125001",
      "amount": 2000,
      "status": "credited",
      "earned_at": "2024-11-25T14:30:00Z"
    }
  ]
}
```

### POST /api/rewards/withdraw/
Request reward withdrawal.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "amount": 5000,
  "upi_id": "john.doe@paytm"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "Withdrawal request submitted",
  "withdrawal": {
    "id": "674a8b2d1234567890abcdef",
    "amount": 5000,
    "upi_id": "john.doe@paytm",
    "status": "pending",
    "requested_at": "2024-11-25T15:30:00Z"
  }
}
```

## Payment Endpoints

### POST /api/payments/create-order/
Create payment order for challan.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "violation_id": "674a8b2d1234567890abcdef",
  "amount": 5000
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "order_id": "order_674a8b2d1234567890abcdef",
  "amount": 5000,
  "currency": "INR",
  "razorpay_order_id": "order_LdD8j5dGHb3kpQ"
}
```

### POST /api/payments/verify/
Verify payment after successful transaction.

**Request Body:**
```json
{
  "razorpay_order_id": "order_LdD8j5dGHb3kpQ",
  "razorpay_payment_id": "pay_LdD8j5dGHb3kpQ",
  "razorpay_signature": "signature_string"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Payment verified successfully",
  "payment_status": "completed"
}
```

## File Management

### GET /api/files/{file_id}/
Download evidence file.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
Returns the actual file content with appropriate Content-Type header.

## Officer Dashboard (Admin)

### GET /api/admin/violations/pending/
Get violations pending review.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `page`: Page number
- `severity`: Filter by severity level
- `location`: Filter by location

**Response (200 OK):**
```json
{
  "count": 50,
  "results": [
    {
      "id": "674a8b2d1234567890abcdef",
      "violation_id": "VIO20241125001",
      "violation_type": "helmet",
      "location": {
        "address": "MG Road, Bangalore"
      },
      "submitted_at": "2024-11-25T10:30:00Z",
      "ai_confidence": 0.95,
      "priority": "high"
    }
  ]
}
```

### POST /api/admin/violations/{id}/verify/
Verify a violation report.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "status": "verified",
  "challan_amount": 5000,
  "comments": "Clear violation, issuing challan"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Violation verified successfully",
  "challan_id": "CHAL20241125001"
}
```

## Analytics Endpoints

### GET /api/analytics/dashboard/
Get dashboard statistics.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "total_violations": 1250,
  "verified_violations": 980,
  "total_rewards": 392000,
  "recent_activity": [
    {
      "type": "violation_submitted",
      "count": 15,
      "date": "2024-11-25"
    }
  ],
  "violation_types": {
    "helmet": 450,
    "traffic_signal": 320,
    "wrong_way": 210,
    "overspeeding": 270
  }
}
```

## Error Responses

### 400 Bad Request
```json
{
  "success": false,
  "error": "Invalid request data",
  "details": {
    "phone_number": ["This field is required."]
  }
}
```

### 401 Unauthorized
```json
{
  "success": false,
  "error": "Authentication required",
  "message": "Please provide a valid access token"
}
```

### 403 Forbidden
```json
{
  "success": false,
  "error": "Permission denied",
  "message": "You don't have permission to access this resource"
}
```

### 404 Not Found
```json
{
  "success": false,
  "error": "Resource not found",
  "message": "The requested violation does not exist"
}
```

### 500 Internal Server Error
```json
{
  "success": false,
  "error": "Internal server error",
  "message": "An unexpected error occurred"
}
```

## Rate Limiting

- **Authentication endpoints:** 5 requests per minute
- **Violation submission:** 10 requests per hour
- **General API:** 100 requests per minute

Rate limit headers included in response:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1700900000
```

## WebSocket Events

### Connection
```javascript
const ws = new WebSocket('wss://api.snapchallan.com/ws/notifications/');
```

### Events

#### violation_status_update
```json
{
  "type": "violation_status_update",
  "data": {
    "violation_id": "674a8b2d1234567890abcdef",
    "status": "verified",
    "message": "Your violation report has been verified"
  }
}
```

#### reward_credited
```json
{
  "type": "reward_credited",
  "data": {
    "amount": 2000,
    "violation_id": "674a8b2d1234567890abcdef",
    "message": "Reward of ₹2000 credited to your account"
  }
}
```

## SDK Examples

### JavaScript
```javascript
class SnapChallanAPI {
  constructor(baseURL, token) {
    this.baseURL = baseURL;
    this.token = token;
  }

  async submitViolation(data) {
    const formData = new FormData();
    Object.keys(data).forEach(key => {
      formData.append(key, data[key]);
    });

    const response = await fetch(`${this.baseURL}/api/violations/`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.token}`
      },
      body: formData
    });

    return response.json();
  }
}
```

### Python
```python
import requests

class SnapChallanAPI:
    def __init__(self, base_url, token):
        self.base_url = base_url
        self.token = token
        self.headers = {'Authorization': f'Bearer {token}'}
    
    def submit_violation(self, data, files):
        return requests.post(
            f'{self.base_url}/api/violations/',
            data=data,
            files=files,
            headers=self.headers
        ).json()
```

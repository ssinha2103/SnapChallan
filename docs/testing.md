# SnapChallan Testing Guide

## Test Suite Overview

The SnapChallan platform includes comprehensive testing across all components:
- **Backend API Tests**: Django unit, integration, and API tests
- **Frontend Tests**: JavaScript unit tests and end-to-end tests
- **AI Service Tests**: Computer vision model validation
- **Load Testing**: Performance and scalability testing
- **Security Testing**: Penetration testing and vulnerability scanning

## Backend Testing

### Setup Test Environment

```bash
cd backend
python -m venv test_env
source test_env/bin/activate  # On Windows: test_env\Scripts\activate
pip install -r requirements.txt
pip install coverage pytest-django
```

### Running Tests

```bash
# Run all tests
python manage.py test

# Run specific test module
python manage.py test apps.authentication.tests

# Run with coverage
coverage run --source='.' manage.py test
coverage report
coverage html  # Generates HTML coverage report
```

### Test Structure

```
backend/
├── apps/
│   ├── authentication/
│   │   └── tests/
│   │       ├── test_models.py
│   │       ├── test_views.py
│   │       ├── test_serializers.py
│   │       └── test_kyc.py
│   ├── violations/
│   │   └── tests/
│   │       ├── test_models.py
│   │       ├── test_views.py
│   │       ├── test_api.py
│   │       └── test_file_handling.py
│   └── payments/
│       └── tests/
│           ├── test_razorpay.py
│           ├── test_upi.py
│           └── test_webhooks.py
└── tests/
    ├── test_integration.py
    └── test_performance.py
```

### Sample Test Cases

#### Authentication Tests

```python
# apps/authentication/tests/test_views.py
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model

User = get_user_model()

class AuthenticationTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.register_url = reverse('auth:register')
        self.login_url = reverse('auth:login')
    
    def test_user_registration(self):
        """Test user registration with valid data"""
        data = {
            'phone_number': '+919876543210',
            'password': 'SecurePass123!',
            'first_name': 'John',
            'last_name': 'Doe',
            'email': 'john@example.com'
        }
        response = self.client.post(self.register_url, data)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(phone_number='+919876543210').exists())
    
    def test_duplicate_phone_registration(self):
        """Test registration with duplicate phone number"""
        User.objects.create_user(
            phone_number='+919876543210',
            password='password'
        )
        data = {
            'phone_number': '+919876543210',
            'password': 'SecurePass123!',
            'first_name': 'Jane',
            'last_name': 'Doe'
        }
        response = self.client.post(self.register_url, data)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
    
    def test_login_valid_credentials(self):
        """Test login with valid credentials"""
        user = User.objects.create_user(
            phone_number='+919876543210',
            password='SecurePass123!',
            is_verified=True
        )
        data = {
            'phone_number': '+919876543210',
            'password': 'SecurePass123!'
        }
        response = self.client.post(self.login_url, data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('tokens', response.data)
    
    def test_kyc_verification(self):
        """Test Aadhaar KYC verification"""
        user = User.objects.create_user(
            phone_number='+919876543210',
            password='password',
            is_verified=True
        )
        self.client.force_authenticate(user=user)
        
        # Mock KYC verification
        data = {
            'aadhaar_number': '123456789012',
            'name': 'John Doe',
            'otp': '123456'
        }
        response = self.client.post('/api/auth/kyc/verify/', data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
```

#### Violation Tests

```python
# apps/violations/tests/test_api.py
from django.test import TestCase
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APIClient
from rest_framework import status
from django.contrib.auth import get_user_model
from apps.violations.models import Violation

User = get_user_model()

class ViolationAPITestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            phone_number='+919876543210',
            password='password',
            is_verified=True,
            aadhaar_verified=True
        )
        self.client.force_authenticate(user=self.user)
    
    def test_submit_violation_with_image(self):
        """Test violation submission with image evidence"""
        # Create test image
        image_content = b'fake image content'
        image = SimpleUploadedFile(
            "test_image.jpg",
            image_content,
            content_type="image/jpeg"
        )
        
        data = {
            'description': 'Vehicle running red light',
            'violation_type': 'traffic_signal',
            'location_latitude': 28.6139,
            'location_longitude': 77.2090,
            'location_address': 'India Gate, New Delhi',
            'evidence_file': image
        }
        
        response = self.client.post('/api/violations/', data, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(Violation.objects.filter(submitted_by=self.user).exists())
    
    def test_get_user_violations(self):
        """Test fetching user's violations"""
        Violation.objects.create(
            submitted_by=self.user,
            description='Test violation',
            violation_type='helmet',
            location_latitude=28.6139,
            location_longitude=77.2090
        )
        
        response = self.client.get('/api/violations/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data['results']), 1)
```

### Performance Tests

```python
# tests/test_performance.py
from django.test import TestCase
from django.test.utils import override_settings
from django.contrib.auth import get_user_model
import time

User = get_user_model()

class PerformanceTestCase(TestCase):
    def test_bulk_user_creation(self):
        """Test bulk user creation performance"""
        start_time = time.time()
        
        users = []
        for i in range(1000):
            users.append(User(
                phone_number=f'+91987654{i:04d}',
                first_name=f'User{i}',
                email=f'user{i}@example.com'
            ))
        
        User.objects.bulk_create(users)
        
        end_time = time.time()
        execution_time = end_time - start_time
        
        self.assertLess(execution_time, 5.0)  # Should complete in under 5 seconds
        self.assertEqual(User.objects.count(), 1000)
```

## Frontend Testing

### Setup Test Environment

```bash
cd frontend
npm install --save-dev jest @testing-library/dom @testing-library/jest-dom
```

### Test Configuration

```javascript
// frontend/jest.config.js
module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/tests/setup.js'],
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/js/$1'
  },
  collectCoverageFrom: [
    'js/**/*.js',
    '!js/vendor/**',
    '!js/config.js'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  }
};
```

### Sample Frontend Tests

```javascript
// frontend/tests/auth.test.js
import { AuthManager } from '../js/auth.js';

describe('AuthManager', () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
  });

  test('should store tokens on login', () => {
    const authManager = new AuthManager();
    const tokens = {
      access: 'access_token',
      refresh: 'refresh_token'
    };

    authManager.setTokens(tokens);

    expect(localStorage.getItem('access_token')).toBe('access_token');
    expect(localStorage.getItem('refresh_token')).toBe('refresh_token');
  });

  test('should return true for valid token', () => {
    const authManager = new AuthManager();
    // Mock valid token
    localStorage.setItem('access_token', 'valid_token');
    
    expect(authManager.isAuthenticated()).toBe(true);
  });

  test('should handle logout correctly', () => {
    const authManager = new AuthManager();
    localStorage.setItem('access_token', 'token');
    localStorage.setItem('refresh_token', 'refresh');

    authManager.logout();

    expect(localStorage.getItem('access_token')).toBeNull();
    expect(localStorage.getItem('refresh_token')).toBeNull();
  });
});
```

### Running Frontend Tests

```bash
cd frontend
npm test
npm run test:coverage
npm run test:watch  # Watch mode for development
```

## AI Service Testing

### Computer Vision Tests

```python
# ai/tests/test_ai_processor.py
import pytest
import cv2
import numpy as np
from unittest.mock import patch, MagicMock
from main import AIProcessor

class TestAIProcessor:
    @pytest.fixture
    def ai_processor(self):
        return AIProcessor()
    
    @pytest.fixture
    def sample_image(self):
        # Create a sample image
        return np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
    
    def test_helmet_detection(self, ai_processor, sample_image):
        """Test helmet detection functionality"""
        with patch.object(ai_processor.helmet_model, 'predict') as mock_predict:
            # Mock YOLO detection results
            mock_results = MagicMock()
            mock_results.boxes.xyxy = [[100, 100, 200, 200]]  # Bounding box
            mock_results.boxes.conf = [0.95]  # Confidence
            mock_results.boxes.cls = [0]  # Class (person)
            mock_predict.return_value = [mock_results]
            
            result = ai_processor.detect_helmet_violation(sample_image)
            
            assert 'helmet_violation' in result
            assert result['confidence'] > 0
    
    def test_license_plate_detection(self, ai_processor, sample_image):
        """Test license plate detection and OCR"""
        with patch.object(ai_processor.plate_model, 'predict') as mock_predict:
            mock_results = MagicMock()
            mock_results.boxes.xyxy = [[150, 150, 250, 200]]
            mock_results.boxes.conf = [0.9]
            mock_predict.return_value = [mock_results]
            
            with patch('easyocr.Reader') as mock_reader:
                mock_reader.return_value.readtext.return_value = [
                    (None, 'DL01AB1234', 0.95)
                ]
                
                result = ai_processor.extract_license_plate(sample_image)
                
                assert 'license_plate' in result
                assert result['license_plate'] == 'DL01AB1234'
    
    def test_violation_analysis_integration(self, ai_processor, sample_image):
        """Test complete violation analysis pipeline"""
        with patch.multiple(
            ai_processor,
            detect_helmet_violation=MagicMock(return_value={
                'helmet_violation': True,
                'confidence': 0.9
            }),
            extract_license_plate=MagicMock(return_value={
                'license_plate': 'DL01AB1234',
                'confidence': 0.85
            })
        ):
            result = ai_processor.analyze_violation(sample_image, 'helmet')
            
            assert result['violation_detected'] is True
            assert 'license_plate' in result
            assert result['overall_confidence'] > 0
```

### AI Model Validation

```python
# ai/tests/test_model_accuracy.py
import pytest
from pathlib import Path
from main import AIProcessor
import json

class TestModelAccuracy:
    @pytest.fixture
    def test_dataset_path(self):
        return Path('tests/data/validation_dataset')
    
    def test_helmet_detection_accuracy(self, test_dataset_path):
        """Test helmet detection model accuracy on validation dataset"""
        ai_processor = AIProcessor()
        correct_predictions = 0
        total_samples = 0
        
        # Load ground truth annotations
        with open(test_dataset_path / 'annotations.json') as f:
            annotations = json.load(f)
        
        for annotation in annotations:
            image_path = test_dataset_path / annotation['image']
            if not image_path.exists():
                continue
                
            image = cv2.imread(str(image_path))
            result = ai_processor.detect_helmet_violation(image)
            
            expected = annotation['helmet_violation']
            predicted = result['helmet_violation']
            
            if expected == predicted:
                correct_predictions += 1
            total_samples += 1
        
        accuracy = correct_predictions / total_samples
        assert accuracy >= 0.85  # Minimum 85% accuracy requirement
```

### Running AI Tests

```bash
cd ai
python -m pytest tests/ -v --cov=main
python -m pytest tests/test_model_accuracy.py -v  # Model validation
```

## Integration Testing

### API Integration Tests

```python
# backend/tests/test_integration.py
from django.test import TestCase, TransactionTestCase
from django.test.utils import override_settings
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
import responses
import json

User = get_user_model()

class FullWorkflowTestCase(TransactionTestCase):
    def setUp(self):
        self.client = APIClient()
    
    def test_complete_violation_workflow(self):
        """Test complete violation submission and processing workflow"""
        # 1. User registration
        register_data = {
            'phone_number': '+919876543210',
            'password': 'SecurePass123!',
            'first_name': 'John',
            'last_name': 'Doe'
        }
        response = self.client.post('/api/auth/register/', register_data)
        self.assertEqual(response.status_code, 201)
        
        # 2. Phone verification (mocked)
        verify_data = {
            'phone_number': '+919876543210',
            'otp': '123456'
        }
        response = self.client.post('/api/auth/verify-otp/', verify_data)
        self.assertEqual(response.status_code, 200)
        
        tokens = response.data['tokens']
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {tokens["access"]}')
        
        # 3. KYC verification (mocked)
        kyc_data = {
            'aadhaar_number': '123456789012',
            'name': 'John Doe',
            'otp': '123456'
        }
        with responses.RequestsMock() as rsps:
            rsps.add(
                responses.POST,
                'https://api.uidai.gov.in/verify',
                json={'status': 'success'},
                status=200
            )
            response = self.client.post('/api/auth/kyc/verify/', kyc_data)
            self.assertEqual(response.status_code, 200)
        
        # 4. Submit violation
        violation_data = {
            'description': 'Vehicle running red light',
            'violation_type': 'traffic_signal',
            'location_latitude': 28.6139,
            'location_longitude': 77.2090,
            'location_address': 'India Gate, New Delhi'
        }
        response = self.client.post('/api/violations/', violation_data)
        self.assertEqual(response.status_code, 201)
        
        violation_id = response.data['violation']['id']
        
        # 5. Officer verification (admin user)
        admin_user = User.objects.create_user(
            phone_number='+919876543211',
            password='admin',
            role='officer',
            is_staff=True
        )
        self.client.force_authenticate(user=admin_user)
        
        verify_data = {
            'status': 'verified',
            'challan_amount': 5000,
            'comments': 'Clear violation, issuing challan'
        }
        response = self.client.post(f'/api/admin/violations/{violation_id}/verify/', verify_data)
        self.assertEqual(response.status_code, 200)
        
        # 6. Check reward credited
        self.client.force_authenticate(user=User.objects.get(phone_number='+919876543210'))
        response = self.client.get('/api/rewards/')
        self.assertEqual(response.status_code, 200)
        self.assertGreater(response.data['total_earned'], 0)
```

## Load Testing

### Artillery Configuration

```yaml
# tests/performance/load-test.yml
config:
  target: 'http://localhost:8000'
  phases:
    - duration: 60
      arrivalRate: 1
      name: "Warm up"
    - duration: 300
      arrivalRate: 5
      rampTo: 50
      name: "Ramp up load"
    - duration: 600
      arrivalRate: 50
      name: "Sustained load"
  payload:
    path: "./users.csv"
    fields:
      - "phone_number"
      - "password"

scenarios:
  - name: "User registration and violation submission"
    weight: 70
    flow:
      - post:
          url: "/api/auth/register/"
          json:
            phone_number: "{{ phone_number }}"
            password: "{{ password }}"
            first_name: "Test"
            last_name: "User"
      - post:
          url: "/api/auth/verify-otp/"
          json:
            phone_number: "{{ phone_number }}"
            otp: "123456"
          capture:
            - json: "$.tokens.access"
              as: "access_token"
      - post:
          url: "/api/violations/"
          headers:
            Authorization: "Bearer {{ access_token }}"
          json:
            description: "Test violation"
            violation_type: "helmet"
            location_latitude: 28.6139
            location_longitude: 77.2090

  - name: "API browsing"
    weight: 30
    flow:
      - post:
          url: "/api/auth/login/"
          json:
            phone_number: "{{ phone_number }}"
            password: "{{ password }}"
          capture:
            - json: "$.tokens.access"
              as: "access_token"
      - get:
          url: "/api/violations/"
          headers:
            Authorization: "Bearer {{ access_token }}"
      - get:
          url: "/api/rewards/"
          headers:
            Authorization: "Bearer {{ access_token }}"
```

### Running Load Tests

```bash
# Install Artillery
npm install -g artillery

# Run load test
artillery run tests/performance/load-test.yml

# Generate HTML report
artillery run tests/performance/load-test.yml --output report.json
artillery report report.json
```

## Security Testing

### OWASP ZAP Integration

```python
# tests/security/test_security.py
import subprocess
import json
from django.test import TestCase
from django.test.utils import override_settings

class SecurityTestCase(TestCase):
    def test_zap_baseline_scan(self):
        """Run OWASP ZAP baseline security scan"""
        result = subprocess.run([
            'docker', 'run', '-t', 'owasp/zap2docker-stable',
            'zap-baseline.py', '-t', 'http://localhost:8000',
            '-J', 'zap-report.json'
        ], capture_output=True, text=True)
        
        # Parse results and assert no high-risk vulnerabilities
        with open('zap-report.json') as f:
            report = json.load(f)
        
        high_risk_alerts = [
            alert for alert in report.get('site', [{}])[0].get('alerts', [])
            if alert.get('riskdesc', '').startswith('High')
        ]
        
        self.assertEqual(len(high_risk_alerts), 0, 
                        f"High-risk vulnerabilities found: {high_risk_alerts}")
```

### Penetration Testing Checklist

1. **Authentication Security**
   - JWT token validation
   - Session management
   - Password policy enforcement
   - Rate limiting on auth endpoints

2. **API Security**
   - Input validation
   - SQL injection prevention
   - XSS protection
   - CSRF protection

3. **File Upload Security**
   - File type validation
   - Size limits
   - Malware scanning
   - Path traversal prevention

4. **Data Privacy**
   - PII encryption
   - Aadhaar data hashing
   - GDPR compliance
   - Data retention policies

## Continuous Integration

### GitHub Actions Test Workflow

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    services:
      mongodb:
        image: mongo:7.0
        env:
          MONGO_INITDB_ROOT_USERNAME: admin
          MONGO_INITDB_ROOT_PASSWORD: admin123
        ports:
          - 27017:27017

    steps:
    - uses: actions/checkout@v4
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.12'
    
    - name: Install dependencies
      run: |
        cd backend
        pip install -r requirements.txt
        pip install coverage
    
    - name: Run tests with coverage
      run: |
        cd backend
        coverage run --source='.' manage.py test
        coverage xml
    
    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./backend/coverage.xml

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
    
    - name: Install and test
      run: |
        cd frontend
        npm install
        npm test
```

## Test Data Management

### Fixtures

```python
# backend/fixtures/test_data.py
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from apps.violations.models import Violation

User = get_user_model()

class Command(BaseCommand):
    def handle(self, *args, **options):
        # Create test users
        test_user = User.objects.create_user(
            phone_number='+919876543210',
            password='testpass123',
            first_name='Test',
            last_name='User',
            is_verified=True,
            aadhaar_verified=True
        )
        
        # Create test violations
        Violation.objects.create(
            submitted_by=test_user,
            description='Test helmet violation',
            violation_type='helmet',
            location_latitude=28.6139,
            location_longitude=77.2090,
            status='verified',
            challan_amount=1000
        )
        
        self.stdout.write('Test data created successfully')
```

### Running Test Data Creation

```bash
cd backend
python manage.py test_data
```

## Test Reports and Coverage

### Coverage Configuration

```ini
# backend/.coveragerc
[run]
source = .
omit = 
    */venv/*
    */migrations/*
    manage.py
    */settings/*
    */tests/*
    */node_modules/*

[report]
exclude_lines =
    pragma: no cover
    def __repr__
    if self.debug:
    if settings.DEBUG
    raise AssertionError
    raise NotImplementedError
```

### Generating Reports

```bash
# Backend coverage
cd backend
coverage run --source='.' manage.py test
coverage report
coverage html  # HTML report in htmlcov/

# Frontend coverage
cd frontend
npm run test:coverage
```

This comprehensive testing guide ensures that all aspects of the SnapChallan platform are thoroughly tested, from individual unit tests to full integration workflows and performance validation.

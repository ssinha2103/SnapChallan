# Contributing to SnapChallan

We welcome contributions to the SnapChallan platform! This document provides guidelines for contributing to the project.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Code Style Guidelines](#code-style-guidelines)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Security Vulnerabilities](#security-vulnerabilities)
- [Community Guidelines](#community-guidelines)

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Git** installed and configured
- **Docker** and Docker Compose for local development
- **Python 3.12+** for backend development
- **Node.js 18+** for frontend development
- **MongoDB 7.x** for database operations
- **Basic understanding** of Django, React/JavaScript, and computer vision concepts

### Fork and Clone

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/SnapChallan.git
   cd SnapChallan
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/original-owner/SnapChallan.git
   ```

## Development Environment

### Quick Setup with Docker

```bash
# Copy environment configuration
cp .env.example .env

# Start all services
docker-compose up -d

# Initialize database
docker-compose exec backend python manage.py migrate
docker-compose exec backend python manage.py create_admin
```

### Manual Setup

#### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Database setup
python manage.py migrate
python manage.py collectstatic
python manage.py runserver
```

#### Frontend Setup

```bash
cd frontend
npm install
npm run dev
```

#### AI Service Setup

```bash
cd ai
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8001
```

## Code Style Guidelines

### Python (Backend & AI Service)

We follow **PEP 8** with some modifications:

```python
# Use Black formatter with line length 88
pip install black isort flake8

# Format code
black . --line-length 88
isort . --profile black

# Linting
flake8 . --max-line-length=88 --extend-ignore=E203,W503
```

#### Django Best Practices

```python
# Models
class Violation(models.Model):
    """Model representing a traffic violation report."""
    
    submitted_by = models.ForeignKey(
        User, 
        on_delete=models.CASCADE,
        help_text="User who submitted the violation"
    )
    
    class Meta:
        db_table = "violations"
        verbose_name = "Traffic Violation"
        verbose_name_plural = "Traffic Violations"

# Views
class ViolationViewSet(viewsets.ModelViewSet):
    """ViewSet for managing violation reports."""
    
    serializer_class = ViolationSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        """Return violations for the current user."""
        return Violation.objects.filter(submitted_by=self.request.user)
```

#### Error Handling

```python
# Use specific exceptions
from django.core.exceptions import ValidationError
from rest_framework.exceptions import NotFound

def verify_violation(violation_id):
    try:
        violation = Violation.objects.get(id=violation_id)
    except Violation.DoesNotExist:
        raise NotFound("Violation not found")
    
    if violation.status != 'pending':
        raise ValidationError("Violation already processed")
```

### JavaScript (Frontend)

We use **ESLint** and **Prettier** for code formatting:

```javascript
// Use modern ES6+ syntax
class AuthManager {
  constructor() {
    this.token = localStorage.getItem('access_token');
  }

  async login(credentials) {
    try {
      const response = await fetch('/api/auth/login/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(credentials),
      });

      if (!response.ok) {
        throw new Error('Login failed');
      }

      const data = await response.json();
      this.setTokens(data.tokens);
      return data;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  }
}

// Use descriptive variable names
const violationSubmissionForm = document.getElementById('violation-form');
const evidenceFileInput = document.getElementById('evidence-file');

// Prefer const/let over var
const API_BASE_URL = '/api';
let currentUser = null;
```

### CSS Guidelines

```css
/* Use BEM naming convention */
.violation-card {
  padding: 1rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.violation-card__header {
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: 0.5rem;
}

.violation-card__status--verified {
  color: #10b981;
  font-weight: 500;
}

/* Use CSS custom properties for theming */
:root {
  --primary-color: #3b82f6;
  --success-color: #10b981;
  --error-color: #ef4444;
  --warning-color: #f59e0b;
}
```

## Making Changes

### Branch Naming

Use descriptive branch names:

```bash
# Feature branches
git checkout -b feature/user-authentication
git checkout -b feature/ai-helmet-detection

# Bug fixes
git checkout -b fix/violation-upload-error
git checkout -b fix/payment-validation

# Documentation
git checkout -b docs/api-documentation
git checkout -b docs/deployment-guide
```

### Commit Messages

Follow the **Conventional Commits** specification:

```bash
# Format: type(scope): description

# Features
git commit -m "feat(auth): add Aadhaar KYC verification"
git commit -m "feat(ai): implement helmet detection algorithm"

# Bug fixes
git commit -m "fix(violations): resolve file upload timeout issue"
git commit -m "fix(payments): handle Razorpay webhook validation"

# Documentation
git commit -m "docs(api): add violation endpoints documentation"

# Tests
git commit -m "test(auth): add unit tests for JWT authentication"

# Refactoring
git commit -m "refactor(ai): optimize image processing pipeline"
```

### Code Changes Checklist

Before submitting changes:

- [ ] **Code follows style guidelines**
- [ ] **All tests pass**
- [ ] **New tests added for new functionality**
- [ ] **Documentation updated**
- [ ] **No console.log or debug statements**
- [ ] **Security considerations addressed**
- [ ] **Performance impact evaluated**

## Testing

### Running Tests

```bash
# Backend tests
cd backend
python manage.py test
coverage run --source='.' manage.py test
coverage report

# Frontend tests
cd frontend
npm test
npm run test:coverage

# AI service tests
cd ai
python -m pytest tests/ -v

# Integration tests
docker-compose -f docker-compose.test.yml up --abort-on-container-exit
```

### Writing Tests

#### Backend Tests

```python
# apps/violations/tests/test_views.py
from django.test import TestCase
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

User = get_user_model()

class ViolationAPITestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            phone_number='+919876543210',
            password='testpass'
        )
        self.client.force_authenticate(user=self.user)
    
    def test_submit_violation(self):
        """Test violation submission endpoint."""
        data = {
            'description': 'Test violation',
            'violation_type': 'helmet',
            'location_latitude': 28.6139,
            'location_longitude': 77.2090
        }
        response = self.client.post('/api/violations/', data)
        self.assertEqual(response.status_code, 201)
```

#### Frontend Tests

```javascript
// frontend/tests/auth.test.js
import { AuthManager } from '../js/auth.js';

describe('AuthManager', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  test('should store tokens on login', () => {
    const authManager = new AuthManager();
    const tokens = { access: 'token', refresh: 'refresh' };
    
    authManager.setTokens(tokens);
    
    expect(localStorage.getItem('access_token')).toBe('token');
  });
});
```

## Pull Request Process

### Before Submitting

1. **Sync with upstream**:
   ```bash
   git fetch upstream
   git checkout main
   git merge upstream/main
   git checkout your-feature-branch
   git rebase main
   ```

2. **Run all tests**:
   ```bash
   # Run complete test suite
   ./scripts/run-all-tests.sh
   ```

3. **Update documentation**:
   - Update relevant `.md` files
   - Add inline code documentation
   - Update API documentation if needed

### Pull Request Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## How Has This Been Tested?
- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual testing

## Checklist
- [ ] My code follows the style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes

## Screenshots (if applicable)
Add screenshots to help explain your changes.

## Additional Notes
Any additional information or context about the changes.
```

### Review Process

1. **Automated checks** must pass:
   - Code linting
   - Test suite
   - Security scan
   - Build verification

2. **Peer review** requirements:
   - At least 2 reviewers for major changes
   - At least 1 reviewer for minor changes
   - Security team review for security-related changes

3. **Merge requirements**:
   - All conversations resolved
   - All checks passing
   - Branch up-to-date with main
   - Squash commits if requested

## Issue Reporting

### Bug Reports

Use the bug report template:

```markdown
**Bug Description**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected Behavior**
A clear description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Environment:**
- OS: [e.g. iOS]
- Browser [e.g. chrome, safari]
- Version [e.g. 22]
- Device: [e.g. iPhone6]

**Additional Context**
Add any other context about the problem here.
```

### Feature Requests

Use the feature request template:

```markdown
**Is your feature request related to a problem? Please describe.**
A clear and concise description of what the problem is.

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

**Describe alternatives you've considered**
A clear and concise description of any alternative solutions.

**Additional context**
Add any other context or screenshots about the feature request here.
```

## Security Vulnerabilities

### Reporting Security Issues

**DO NOT** open a public issue for security vulnerabilities.

Instead:

1. **Email security team**: security@snapchallan.com
2. **Include details**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

3. **Response timeline**:
   - Acknowledgment: 24 hours
   - Initial assessment: 72 hours
   - Status updates: Weekly

### Security Guidelines

When contributing:

- **Never commit secrets** (API keys, passwords, etc.)
- **Validate all user inputs**
- **Use parameterized queries** to prevent SQL injection
- **Implement proper authentication** and authorization
- **Follow OWASP guidelines**
- **Use HTTPS** for all communications
- **Sanitize file uploads**
- **Implement rate limiting**

## Community Guidelines

### Code of Conduct

We are committed to providing a welcoming and inclusive environment:

1. **Be respectful** and considerate of others
2. **Use inclusive language**
3. **Accept constructive criticism** gracefully
4. **Focus on what's best** for the community
5. **Show empathy** towards other community members

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and community discussion
- **Slack**: Real-time development discussion (invite only)
- **Email**: security@snapchallan.com for security issues

### Recognition

Contributors will be recognized in:

- **CONTRIBUTORS.md** file
- **Release notes** for significant contributions
- **Annual contributor highlights**

## Getting Help

If you need help with contributing:

1. **Check existing documentation**
2. **Search closed issues and PRs**
3. **Ask in GitHub Discussions**
4. **Reach out to maintainers**

## Development Tools

### Recommended IDE Setup

**VS Code Extensions**:
```json
{
  "recommendations": [
    "ms-python.python",
    "ms-python.black-formatter",
    "ms-python.isort",
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "bradlc.vscode-tailwindcss",
    "ms-vscode.vscode-json"
  ]
}
```

### Pre-commit Hooks

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run hooks manually
pre-commit run --all-files
```

### Debugging

#### Backend Debugging

```python
# Use Django debug toolbar for development
if settings.DEBUG:
    import debug_toolbar
    urlpatterns = [
        path('__debug__/', include(debug_toolbar.urls)),
    ] + urlpatterns
```

#### Frontend Debugging

```javascript
// Use browser dev tools
console.log('Debug info:', debugData);

// For production builds, use source maps
// webpack.config.js
module.exports = {
  devtool: 'source-map',
  // ... other config
};
```

Thank you for contributing to SnapChallan! Your efforts help make traffic monitoring more effective and community-driven.

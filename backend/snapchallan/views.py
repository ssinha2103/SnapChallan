from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import csrf_exempt
import json

@require_http_methods(["GET"])
def home_view(request):
    """
    Home page view - provides basic API information
    """
    return JsonResponse({
        'message': 'Welcome to SnapChallan API',
        'version': '1.0.0',
        'status': 'running',
        'endpoints': {
            'admin': '/admin/',
            'authentication': '/api/auth/',
            'violations': '/api/violations/',
            'payments': '/api/payments/',
            'ai_processing': '/api/ai/',
            'officers': '/api/officers/',
            'notifications': '/api/notifications/',
        }
    })

@require_http_methods(["GET"])
def health_check(request):
    """
    Health check endpoint
    """
    return JsonResponse({
        'status': 'healthy',
        'timestamp': '2025-07-16T12:34:00Z'
    })

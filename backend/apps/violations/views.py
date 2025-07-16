from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import csrf_exempt
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from .models import ViolationType

@api_view(['GET'])
@permission_classes([AllowAny])
def violation_types_list(request):
    """
    Get all available violation types
    """
    violation_types = ViolationType.objects.all().values(
        'id', 'name', 'code', 'description', 'fine_amount'
    )
    return Response(list(violation_types))

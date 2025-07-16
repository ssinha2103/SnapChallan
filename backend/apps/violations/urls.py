from django.urls import path
from . import views

app_name = 'violations'

urlpatterns = [
    path('types/', views.violation_types_list, name='violation_types_list'),
]

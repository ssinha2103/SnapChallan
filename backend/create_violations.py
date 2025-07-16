from apps.violations.models import ViolationType

violation_types = [
    {'name': 'Speeding', 'code': 'SP001', 'description': 'Driving above speed limit', 'fine_amount': 500.00, 'ai_detectable': True},
    {'name': 'Red Light Violation', 'code': 'RL001', 'description': 'Running red traffic signal', 'fine_amount': 1000.00, 'ai_detectable': True},
    {'name': 'Wrong Way Driving', 'code': 'WW001', 'description': 'Driving in wrong direction', 'fine_amount': 2000.00, 'ai_detectable': True},
    {'name': 'No Helmet', 'code': 'NH001', 'description': 'Riding without helmet', 'fine_amount': 500.00, 'ai_detectable': True},
    {'name': 'Mobile Phone Usage', 'code': 'MP001', 'description': 'Using mobile phone while driving', 'fine_amount': 1000.00, 'ai_detectable': True},
    {'name': 'Lane Violation', 'code': 'LV001', 'description': 'Improper lane changing', 'fine_amount': 300.00, 'ai_detectable': False},
    {'name': 'Parking Violation', 'code': 'PV001', 'description': 'Illegal parking', 'fine_amount': 200.00, 'ai_detectable': False},
    {'name': 'Triple Riding', 'code': 'TR001', 'description': 'More than 2 people on motorcycle', 'fine_amount': 500.00, 'ai_detectable': True}
]

for vt_data in violation_types:
    obj, created = ViolationType.objects.get_or_create(code=vt_data['code'], defaults=vt_data)
    if created:
        print(f'Created: {obj.name}')
    else:
        print(f'Already exists: {obj.name}')

print(f'Total violation types: {ViolationType.objects.count()}')

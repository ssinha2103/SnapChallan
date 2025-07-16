# SnapChallan Deployment Guide

## Prerequisites

### System Requirements
- Docker 24.0+ and Docker Compose
- Kubernetes cluster (for production)
- MongoDB 7.x
- Redis 7.x
- NVIDIA GPU (for AI processing)

### Environment Setup
1. Copy environment template:
   ```bash
   cp .env.example .env
   ```

2. Configure environment variables:
   ```bash
   # Database
   MONGO_URI=mongodb://admin:admin123@mongodb:27017/snapchallan?authSource=admin
   
   # AI Service
   AI_SERVICE_URL=http://ai:8001
   ENABLE_GPU=true
   
   # Aadhaar eKYC (Production)
   AADHAAR_API_URL=https://api.uidai.gov.in
   AADHAAR_API_KEY=your_production_key
   
   # Payment Gateway
   RAZORPAY_KEY_ID=your_razorpay_key_id
   RAZORPAY_KEY_SECRET=your_razorpay_secret
   
   # Email
   EMAIL_HOST=smtp.gmail.com
   EMAIL_USER=your_email@gmail.com
   EMAIL_PASSWORD=your_app_password
   
   # Security
   SECRET_KEY=your_very_secure_secret_key_here
   ALLOWED_HOSTS=localhost,127.0.0.1,your-domain.com
   ```

## Development Deployment

### Using Docker Compose
1. **Start all services:**
   ```bash
   docker-compose up -d
   ```

2. **Initialize database:**
   ```bash
   docker-compose exec backend python manage.py migrate
   docker-compose exec backend python manage.py create_admin
   ```

3. **Access services:**
   - Frontend: http://localhost:8000
   - Backend API: http://localhost:8000/api
   - AI Service: http://localhost:8001
   - Grafana: http://localhost:3000 (admin/admin)

### Manual Setup
1. **Backend:**
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   python manage.py migrate
   python manage.py runserver
   ```

2. **AI Service:**
   ```bash
   cd ai
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   uvicorn main:app --host 0.0.0.0 --port 8001
   ```

3. **Frontend:**
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

## Production Deployment

### Kubernetes Deployment

1. **Create namespace:**
   ```bash
   kubectl create namespace snapchallan
   ```

2. **Configure secrets:**
   ```bash
   kubectl create secret generic snapchallan-secrets \
     --from-env-file=.env \
     -n snapchallan
   ```

3. **Deploy infrastructure:**
   ```bash
   # Database and cache
   kubectl apply -f infra/k8s/production/mongodb.yaml
   kubectl apply -f infra/k8s/production/redis.yaml
   
   # Wait for databases to be ready
   kubectl wait --for=condition=ready pod -l app=mongodb -n snapchallan --timeout=300s
   kubectl wait --for=condition=ready pod -l app=redis -n snapchallan --timeout=300s
   ```

4. **Deploy applications:**
   ```bash
   # Backend API
   kubectl apply -f infra/k8s/production/backend.yaml
   
   # AI Service
   kubectl apply -f infra/k8s/production/ai.yaml
   
   # Frontend (if using Kubernetes for static files)
   kubectl apply -f infra/k8s/production/frontend.yaml
   
   # Ingress and load balancer
   kubectl apply -f infra/k8s/production/ingress.yaml
   ```

5. **Initialize database:**
   ```bash
   kubectl exec -it deployment/snapchallan-backend -n snapchallan -- python manage.py migrate
   kubectl exec -it deployment/snapchallan-backend -n snapchallan -- python manage.py create_admin
   ```

### Cloud Provider Specific

#### AWS EKS
```bash
# Create EKS cluster
eksctl create cluster --name snapchallan --region us-west-2 --nodegroup-name standard-workers --node-type m5.large --nodes 3

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name snapchallan

# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=snapchallan
```

#### Google GKE
```bash
# Create GKE cluster
gcloud container clusters create snapchallan \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-2 \
  --enable-autorepair \
  --enable-autoupgrade

# Get credentials
gcloud container clusters get-credentials snapchallan --zone us-central1-a
```

#### Azure AKS
```bash
# Create resource group
az group create --name snapchallan --location eastus

# Create AKS cluster
az aks create \
  --resource-group snapchallan \
  --name snapchallan \
  --node-count 3 \
  --node-vm-size Standard_B2s \
  --enable-addons monitoring

# Get credentials
az aks get-credentials --resource-group snapchallan --name snapchallan
```

## SSL/TLS Configuration

### Let's Encrypt with cert-manager
1. **Install cert-manager:**
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

2. **Create ClusterIssuer:**
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: admin@yourdomain.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - http01:
           ingress:
             class: nginx
   ```

3. **Update ingress with TLS:**
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: snapchallan-ingress
     annotations:
       cert-manager.io/cluster-issuer: letsencrypt-prod
   spec:
     tls:
     - hosts:
       - api.yourdomain.com
       - yourdomain.com
       secretName: snapchallan-tls
   ```

## Monitoring Setup

### Prometheus and Grafana
1. **Install Prometheus Operator:**
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install prometheus prometheus-community/kube-prometheus-stack \
     --namespace monitoring \
     --create-namespace
   ```

2. **Configure ServiceMonitors:**
   ```bash
   kubectl apply -f infra/k8s/monitoring/
   ```

3. **Access Grafana:**
   ```bash
   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
   # Default: admin/prom-operator
   ```

### Application Metrics
- **Backend metrics:** `/metrics` endpoint (Django Prometheus)
- **AI service metrics:** `/metrics` endpoint (FastAPI Prometheus)
- **Custom dashboards:** Available in `infra/grafana/dashboards/`

## Database Management

### MongoDB Backup
```bash
# Create backup
kubectl exec -it deployment/mongodb -n snapchallan -- mongodump --uri="mongodb://admin:admin123@localhost:27017/snapchallan?authSource=admin" --out /tmp/backup

# Copy backup
kubectl cp snapchallan/mongodb-pod:/tmp/backup ./backup-$(date +%Y%m%d)

# Restore backup
kubectl exec -it deployment/mongodb -n snapchallan -- mongorestore --uri="mongodb://admin:admin123@localhost:27017/snapchallan?authSource=admin" /tmp/backup/snapchallan
```

### Database Migration
```bash
# Run migrations
kubectl exec -it deployment/snapchallan-backend -n snapchallan -- python manage.py migrate

# Create migration
kubectl exec -it deployment/snapchallan-backend -n snapchallan -- python manage.py makemigrations

# Check migration status
kubectl exec -it deployment/snapchallan-backend -n snapchallan -- python manage.py showmigrations
```

## Scaling Configuration

### Horizontal Pod Autoscaler
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: snapchallan-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: snapchallan-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Database Scaling
```bash
# MongoDB replica set
kubectl apply -f infra/k8s/production/mongodb-replica.yaml

# Redis cluster
kubectl apply -f infra/k8s/production/redis-cluster.yaml
```

## Troubleshooting

### Common Issues

1. **Pod not starting:**
   ```bash
   kubectl describe pod <pod-name> -n snapchallan
   kubectl logs <pod-name> -n snapchallan
   ```

2. **Database connection issues:**
   ```bash
   kubectl exec -it deployment/snapchallan-backend -n snapchallan -- python manage.py check --database default
   ```

3. **AI service GPU issues:**
   ```bash
   kubectl exec -it deployment/snapchallan-ai -n snapchallan -- nvidia-smi
   ```

4. **Storage issues:**
   ```bash
   kubectl get pv,pvc -n snapchallan
   ```

### Log Analysis
```bash
# View application logs
kubectl logs -f deployment/snapchallan-backend -n snapchallan

# View AI service logs
kubectl logs -f deployment/snapchallan-ai -n snapchallan

# Aggregated logs with Loki
kubectl port-forward svc/loki 3100:3100 -n monitoring
```

### Performance Tuning

1. **Database optimization:**
   - Enable MongoDB indexes
   - Configure connection pooling
   - Use read replicas for analytics

2. **AI service optimization:**
   - GPU memory management
   - Model caching
   - Batch processing

3. **Backend optimization:**
   - Django cache configuration
   - Database query optimization
   - Celery worker scaling

## Security Hardening

### Network Policies
```bash
kubectl apply -f infra/k8s/security/network-policies.yaml
```

### Pod Security Standards
```bash
kubectl apply -f infra/k8s/security/pod-security.yaml
```

### Secret Management
```bash
# Use external secret management
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace
```

## Maintenance

### Regular Tasks
1. **Update dependencies** (monthly)
2. **Security patches** (as needed)
3. **Database maintenance** (weekly)
4. **Log rotation** (automated)
5. **Backup verification** (weekly)

### Health Checks
- Backend: `/health/`
- AI Service: `/health/`
- Database: MongoDB health check
- Cache: Redis ping

For more detailed troubleshooting and advanced configuration, refer to the component-specific documentation in each service directory.

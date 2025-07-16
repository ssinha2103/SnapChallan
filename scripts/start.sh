#!/bin/bash

# SnapChallan - Start Script
# This script starts the SnapChallan platform services

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default environment
ENVIRONMENT="development"
DETACHED=false
BUILD=false

# Help function
show_help() {
    echo -e "${BLUE}SnapChallan Start Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --env ENV        Environment to start (development|production|test)"
    echo "  -d, --detached       Run in detached mode (background)"
    echo "  -b, --build          Build images before starting"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   # Start development environment"
    echo "  $0 -e production -d  # Start production in background"
    echo "  $0 -b                # Build and start development"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -d|--detached)
            DETACHED=true
            shift
            ;;
        -b|--build)
            BUILD=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(development|production|test)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Use: development, production, or test${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Starting SnapChallan Platform${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo -e "${YELLOW}Project Root: $PROJECT_ROOT${NC}"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if environment file exists
ENV_FILE=".env"
if [[ "$ENVIRONMENT" != "development" ]]; then
    ENV_FILE=".env.$ENVIRONMENT"
fi

if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${YELLOW}⚠️  Environment file $ENV_FILE not found. Creating from template...${NC}"
    if [[ -f ".env.example" ]]; then
        cp ".env.example" "$ENV_FILE"
        echo -e "${GREEN}✅ Created $ENV_FILE from template${NC}"
        echo -e "${YELLOW}📝 Please edit $ENV_FILE with your configuration${NC}"
    else
        echo -e "${RED}❌ No .env.example file found. Please create $ENV_FILE manually.${NC}"
        exit 1
    fi
fi

# Function to start development environment
start_development() {
    echo -e "${BLUE}🔧 Starting Development Environment${NC}"
    
    # Docker Compose file
    COMPOSE_FILE="docker-compose.yml"
    
    # Build if requested
    if [[ "$BUILD" == true ]]; then
        echo -e "${YELLOW}🏗️  Building Docker images...${NC}"
        docker-compose -f "$COMPOSE_FILE" build
    fi
    
    # Start services
    if [[ "$DETACHED" == true ]]; then
        echo -e "${YELLOW}🚀 Starting services in detached mode...${NC}"
        docker-compose -f "$COMPOSE_FILE" up -d
    else
        echo -e "${YELLOW}🚀 Starting services...${NC}"
        docker-compose -f "$COMPOSE_FILE" up
    fi
}

# Function to start production environment
start_production() {
    echo -e "${BLUE}🏭 Starting Production Environment${NC}"
    
    # Check if Kubernetes is available
    if command -v kubectl > /dev/null 2>&1; then
        echo -e "${YELLOW}☸️  Using Kubernetes deployment...${NC}"
        start_kubernetes
    else
        echo -e "${YELLOW}🐳 Using Docker Compose for production...${NC}"
        start_docker_production
    fi
}

# Function to start with Kubernetes
start_kubernetes() {
    echo -e "${BLUE}☸️  Deploying to Kubernetes${NC}"
    
    # Check if namespace exists
    if ! kubectl get namespace snapchallan > /dev/null 2>&1; then
        echo -e "${YELLOW}📦 Creating namespace 'snapchallan'...${NC}"
        kubectl create namespace snapchallan
    fi
    
    # Apply configurations
    echo -e "${YELLOW}🔧 Applying Kubernetes manifests...${NC}"
    kubectl apply -f infra/k8s/production/
    
    # Wait for deployments
    echo -e "${YELLOW}⏳ Waiting for deployments to be ready...${NC}"
    kubectl wait --for=condition=available --timeout=300s deployment --all -n snapchallan
    
    # Show service status
    echo -e "${GREEN}✅ Kubernetes deployment complete${NC}"
    kubectl get pods,services -n snapchallan
}

# Function to start Docker production
start_docker_production() {
    COMPOSE_FILE="docker-compose.prod.yml"
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo -e "${YELLOW}⚠️  Production compose file not found. Using development setup...${NC}"
        COMPOSE_FILE="docker-compose.yml"
    fi
    
    # Build if requested
    if [[ "$BUILD" == true ]]; then
        echo -e "${YELLOW}🏗️  Building production images...${NC}"
        docker-compose -f "$COMPOSE_FILE" build
    fi
    
    # Start services
    if [[ "$DETACHED" == true ]]; then
        echo -e "${YELLOW}🚀 Starting production services in detached mode...${NC}"
        docker-compose -f "$COMPOSE_FILE" up -d
    else
        echo -e "${YELLOW}🚀 Starting production services...${NC}"
        docker-compose -f "$COMPOSE_FILE" up
    fi
}

# Function to start test environment
start_test() {
    echo -e "${BLUE}🧪 Starting Test Environment${NC}"
    
    COMPOSE_FILE="docker-compose.test.yml"
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo -e "${YELLOW}⚠️  Test compose file not found. Creating minimal test setup...${NC}"
        # Create a minimal test compose file
        cat > "$COMPOSE_FILE" << EOF
version: '3.8'
services:
  mongodb-test:
    image: mongo:7.0
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: admin123
    ports:
      - "27018:27017"
    
  redis-test:
    image: redis:7.2-alpine
    ports:
      - "6380:6379"
      
  backend-test:
    build: ./backend
    environment:
      - MONGO_URI=mongodb://admin:admin123@mongodb-test:27017/snapchallan_test?authSource=admin
      - REDIS_URL=redis://redis-test:6379/1
      - DEBUG=True
    depends_on:
      - mongodb-test
      - redis-test
    ports:
      - "8001:8000"
    command: python manage.py test
EOF
    fi
    
    # Run tests
    echo -e "${YELLOW}🧪 Running test suite...${NC}"
    docker-compose -f "$COMPOSE_FILE" up --abort-on-container-exit
}

# Function to initialize database
initialize_database() {
    echo -e "${YELLOW}🗄️  Initializing database...${NC}"
    
    # Wait for backend to be ready
    sleep 10
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        docker-compose exec backend python manage.py migrate
        docker-compose exec backend python manage.py create_admin
    elif command -v kubectl > /dev/null 2>&1 && kubectl get namespace snapchallan > /dev/null 2>&1; then
        kubectl exec -it deployment/snapchallan-backend -n snapchallan -- python manage.py migrate
        kubectl exec -it deployment/snapchallan-backend -n snapchallan -- python manage.py create_admin
    fi
}

# Function to show service URLs
show_service_urls() {
    echo ""
    echo -e "${GREEN}🌟 SnapChallan Services Started Successfully!${NC}"
    echo ""
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        echo -e "${BLUE}📱 Frontend (PWA):${NC}      http://localhost:8000"
        echo -e "${BLUE}🔗 Backend API:${NC}        http://localhost:8000/api"
        echo -e "${BLUE}🤖 AI Service:${NC}         http://localhost:8001"
        echo -e "${BLUE}📊 Grafana:${NC}            http://localhost:3000 (admin/admin)"
        echo -e "${BLUE}🔍 Prometheus:${NC}         http://localhost:9090"
        echo -e "${BLUE}🗄️  MongoDB Express:${NC}    http://localhost:8081"
    elif command -v kubectl > /dev/null 2>&1; then
        echo -e "${BLUE}☸️  Kubernetes Services:${NC}"
        kubectl get services -n snapchallan
    fi
    
    echo ""
    echo -e "${YELLOW}📋 Useful Commands:${NC}"
    echo -e "  View logs:     $0 logs"
    echo -e "  Stop services: $0 stop"
    echo -e "  Restart:       $0 restart"
    echo ""
}

# Function to check service health
check_health() {
    echo -e "${YELLOW}🔍 Checking service health...${NC}"
    
    # Check backend health
    if curl -f http://localhost:8000/health/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend is healthy${NC}"
    else
        echo -e "${RED}❌ Backend health check failed${NC}"
    fi
    
    # Check AI service health
    if curl -f http://localhost:8001/health/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ AI Service is healthy${NC}"
    else
        echo -e "${RED}❌ AI Service health check failed${NC}"
    fi
}

# Main execution
case $ENVIRONMENT in
    development)
        start_development
        ;;
    production)
        start_production
        ;;
    test)
        start_test
        exit 0  # Exit after tests
        ;;
esac

# Post-startup tasks
if [[ "$DETACHED" == true ]]; then
    # Wait a bit for services to start
    sleep 5
    
    # Initialize database if needed
    initialize_database
    
    # Show service information
    show_service_urls
    
    # Check health
    sleep 10
    check_health
else
    echo -e "${YELLOW}💡 Press Ctrl+C to stop all services${NC}"
fi

echo -e "${GREEN}🎉 SnapChallan startup complete!${NC}"

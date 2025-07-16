#!/bin/bash

# SnapChallan - Restart Script
# This script restarts SnapChallan services

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

# Default options
SERVICE="all"
ENVIRONMENT="development"
BUILD=false

# Help function
show_help() {
    echo -e "${BLUE}SnapChallan Restart Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --service NAME   Service to restart (backend|ai|frontend|mongodb|redis|all)"
    echo "  -e, --env ENV        Environment (development|production)"
    echo "  -b, --build          Rebuild images before restarting"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   # Restart all development services"
    echo "  $0 -s backend        # Restart only backend service"
    echo "  $0 -e production     # Restart production environment"
    echo "  $0 -b                # Rebuild and restart"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
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

# Validate service
if [[ ! "$SERVICE" =~ ^(backend|ai|frontend|mongodb|redis|nginx|all)$ ]]; then
    echo -e "${RED}Error: Invalid service '$SERVICE'. Use: backend, ai, frontend, mongodb, redis, nginx, or all${NC}"
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(development|production)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Use: development or production${NC}"
    exit 1
fi

echo -e "${BLUE}🔄 Restarting SnapChallan Services${NC}"
echo -e "${YELLOW}Service: $SERVICE${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
if [[ "$BUILD" == true ]]; then
    echo -e "${YELLOW}Mode: Rebuild and restart${NC}"
fi
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Function to restart Docker Compose services
restart_docker_compose() {
    local compose_file="$1"
    local service_name="$2"
    local env_name="$3"
    
    if [[ ! -f "$compose_file" ]]; then
        echo -e "${RED}❌ Compose file $compose_file not found${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🐳 Restarting $env_name services...${NC}"
    
    if [[ "$BUILD" == true ]]; then
        echo -e "${YELLOW}🏗️  Building images...${NC}"
        if [[ "$service_name" == "all" ]]; then
            docker-compose -f "$compose_file" build
        else
            docker-compose -f "$compose_file" build "$service_name"
        fi
    fi
    
    if [[ "$service_name" == "all" ]]; then
        echo -e "${YELLOW}🔄 Restarting all services...${NC}"
        docker-compose -f "$compose_file" restart
    else
        echo -e "${YELLOW}🔄 Restarting $service_name...${NC}"
        docker-compose -f "$compose_file" restart "$service_name"
    fi
    
    # Wait for services to be ready
    echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
    sleep 5
    
    # Check status
    if [[ "$service_name" == "all" ]]; then
        docker-compose -f "$compose_file" ps
    else
        docker-compose -f "$compose_file" ps "$service_name"
    fi
    
    echo -e "${GREEN}✅ $env_name restart complete${NC}"
}

# Function to restart Kubernetes services
restart_kubernetes() {
    local service_name="$1"
    
    if ! command -v kubectl > /dev/null 2>&1; then
        echo -e "${RED}❌ kubectl not available${NC}"
        return 1
    fi
    
    if ! kubectl get namespace snapchallan > /dev/null 2>&1; then
        echo -e "${RED}❌ SnapChallan namespace not found${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}☸️  Restarting Kubernetes services...${NC}"
    
    if [[ "$service_name" == "all" ]]; then
        # Restart all deployments
        kubectl rollout restart deployment -n snapchallan
        
        # Wait for rollouts to complete
        echo -e "${YELLOW}⏳ Waiting for rollouts to complete...${NC}"
        kubectl rollout status deployment --all -n snapchallan --timeout=300s
    else
        # Map service names to Kubernetes deployments
        local deployment=""
        case $service_name in
            backend)
                deployment="snapchallan-backend"
                ;;
            ai)
                deployment="snapchallan-ai"
                ;;
            mongodb)
                deployment="mongodb"
                ;;
            redis)
                deployment="redis"
                ;;
            nginx)
                deployment="nginx"
                ;;
            *)
                echo -e "${RED}❌ Unknown service for Kubernetes: $service_name${NC}"
                return 1
                ;;
        esac
        
        kubectl rollout restart deployment/$deployment -n snapchallan
        kubectl rollout status deployment/$deployment -n snapchallan --timeout=300s
    fi
    
    # Show pod status
    kubectl get pods -n snapchallan
    
    echo -e "${GREEN}✅ Kubernetes restart complete${NC}"
}

# Function to perform health check after restart
health_check() {
    echo -e "${YELLOW}🏥 Performing health checks...${NC}"
    sleep 10  # Give services time to start
    
    local services=(
        "backend:http://localhost:8000/health/"
        "ai:http://localhost:8001/health/"
    )
    
    for service_info in "${services[@]}"; do
        local svc=$(echo "$service_info" | cut -d: -f1)
        local url=$(echo "$service_info" | cut -d: -f2-)
        
        echo -n -e "${YELLOW}Checking $svc... ${NC}"
        
        local retries=0
        local max_retries=5
        
        while [[ $retries -lt $max_retries ]]; do
            if curl -f -s --max-time 10 "$url" > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Healthy${NC}"
                break
            else
                retries=$((retries + 1))
                if [[ $retries -eq $max_retries ]]; then
                    echo -e "${RED}❌ Unhealthy after $max_retries attempts${NC}"
                else
                    echo -n "."
                    sleep 5
                fi
            fi
        done
    done
    echo ""
}

# Function to show restart summary
show_restart_summary() {
    echo ""
    echo -e "${GREEN}🎉 Restart Summary${NC}"
    echo -e "${YELLOW}Service: $SERVICE${NC}"
    echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Build: $BUILD${NC}"
    echo -e "${YELLOW}Timestamp: $(date)${NC}"
    echo ""
    
    # Show service URLs
    if [[ "$ENVIRONMENT" == "development" ]]; then
        echo -e "${BLUE}🔗 Service URLs:${NC}"
        echo -e "  Frontend (PWA):     http://localhost:8000"
        echo -e "  Backend API:        http://localhost:8000/api"
        echo -e "  AI Service:         http://localhost:8001"
        echo -e "  Grafana:           http://localhost:3000"
        echo ""
    fi
    
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo -e "  Check status:       ./scripts/status.sh"
    echo -e "  View logs:          ./scripts/logs.sh -f"
    echo -e "  Stop services:      ./scripts/stop.sh"
    echo ""
}

# Main execution
if [[ "$ENVIRONMENT" == "development" ]]; then
    restart_docker_compose "docker-compose.yml" "$SERVICE" "Development"
elif [[ "$ENVIRONMENT" == "production" ]]; then
    # Try Kubernetes first, then Docker
    if kubectl get namespace snapchallan > /dev/null 2>&1; then
        restart_kubernetes "$SERVICE"
    else
        # Try production compose file, fallback to regular
        if [[ -f "docker-compose.prod.yml" ]]; then
            restart_docker_compose "docker-compose.prod.yml" "$SERVICE" "Production"
        else
            restart_docker_compose "docker-compose.yml" "$SERVICE" "Production"
        fi
    fi
fi

# Perform health checks
if [[ "$SERVICE" == "all" ]] || [[ "$SERVICE" == "backend" ]] || [[ "$SERVICE" == "ai" ]]; then
    health_check
fi

# Show summary
show_restart_summary

echo -e "${GREEN}✅ Restart operation completed successfully!${NC}"

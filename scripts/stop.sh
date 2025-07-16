#!/bin/bash

# SnapChallan - Stop Script
# This script stops the SnapChallan platform services

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
ENVIRONMENT="development"
REMOVE_VOLUMES=false
REMOVE_IMAGES=false
FORCE=false

# Help function
show_help() {
    echo -e "${BLUE}SnapChallan Stop Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --env ENV        Environment to stop (development|production|test|all)"
    echo "  -v, --volumes        Remove volumes (data will be lost!)"
    echo "  -i, --images         Remove Docker images"
    echo "  -f, --force          Force stop (kill containers)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   # Stop development environment"
    echo "  $0 -e production     # Stop production environment"
    echo "  $0 -v                # Stop and remove volumes"
    echo "  $0 -e all -v -i      # Stop everything and cleanup"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -i|--images)
            REMOVE_IMAGES=true
            shift
            ;;
        -f|--force)
            FORCE=true
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
if [[ ! "$ENVIRONMENT" =~ ^(development|production|test|all)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Use: development, production, test, or all${NC}"
    exit 1
fi

echo -e "${BLUE}🛑 Stopping SnapChallan Platform${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo -e "${YELLOW}Project Root: $PROJECT_ROOT${NC}"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Warning for destructive operations
if [[ "$REMOVE_VOLUMES" == true ]]; then
    echo -e "${RED}⚠️  WARNING: This will remove all data volumes!${NC}"
    echo -e "${RED}⚠️  All database data, uploaded files, and logs will be permanently deleted!${NC}"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        exit 0
    fi
fi

# Function to stop Docker Compose services
stop_docker_compose() {
    local compose_file="$1"
    local env_name="$2"
    
    if [[ -f "$compose_file" ]]; then
        echo -e "${YELLOW}🐳 Stopping $env_name services...${NC}"
        
        if [[ "$FORCE" == true ]]; then
            docker-compose -f "$compose_file" kill
        else
            docker-compose -f "$compose_file" down
        fi
        
        if [[ "$REMOVE_VOLUMES" == true ]]; then
            echo -e "${YELLOW}🗑️  Removing volumes for $env_name...${NC}"
            docker-compose -f "$compose_file" down -v
        fi
        
        echo -e "${GREEN}✅ $env_name services stopped${NC}"
    else
        echo -e "${YELLOW}⚠️  Compose file $compose_file not found, skipping $env_name${NC}"
    fi
}

# Function to stop Kubernetes services
stop_kubernetes() {
    echo -e "${YELLOW}☸️  Stopping Kubernetes services...${NC}"
    
    if command -v kubectl > /dev/null 2>&1; then
        if kubectl get namespace snapchallan > /dev/null 2>&1; then
            if [[ "$FORCE" == true ]]; then
                echo -e "${YELLOW}🔨 Force deleting namespace...${NC}"
                kubectl delete namespace snapchallan --force --grace-period=0
            else
                echo -e "${YELLOW}🗑️  Deleting SnapChallan namespace...${NC}"
                kubectl delete namespace snapchallan
            fi
            echo -e "${GREEN}✅ Kubernetes services stopped${NC}"
        else
            echo -e "${YELLOW}⚠️  SnapChallan namespace not found in Kubernetes${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  kubectl not available, skipping Kubernetes cleanup${NC}"
    fi
}

# Function to cleanup Docker resources
cleanup_docker() {
    echo -e "${YELLOW}🧹 Cleaning up Docker resources...${NC}"
    
    # Remove stopped containers
    echo -e "${YELLOW}🗑️  Removing stopped containers...${NC}"
    docker container prune -f
    
    # Remove unused networks
    echo -e "${YELLOW}🌐 Removing unused networks...${NC}"
    docker network prune -f
    
    if [[ "$REMOVE_IMAGES" == true ]]; then
        echo -e "${YELLOW}🖼️  Removing SnapChallan images...${NC}"
        docker images | grep snapchallan | awk '{print $3}' | xargs -r docker rmi -f
        docker image prune -f
    fi
    
    if [[ "$REMOVE_VOLUMES" == true ]]; then
        echo -e "${YELLOW}💾 Removing unused volumes...${NC}"
        docker volume prune -f
    fi
    
    echo -e "${GREEN}✅ Docker cleanup complete${NC}"
}

# Function to kill all SnapChallan processes
kill_processes() {
    echo -e "${YELLOW}🔪 Killing SnapChallan processes...${NC}"
    
    # Kill Python processes (Django, FastAPI)
    pkill -f "python.*manage.py" 2>/dev/null || true
    pkill -f "uvicorn.*main:app" 2>/dev/null || true
    pkill -f "celery" 2>/dev/null || true
    
    # Kill Node.js processes (if any)
    pkill -f "node.*snapchallan" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Processes killed${NC}"
}

# Function to stop specific environment
stop_environment() {
    local env="$1"
    
    case $env in
        development)
            echo -e "${BLUE}🔧 Stopping Development Environment${NC}"
            stop_docker_compose "docker-compose.yml" "development"
            ;;
        production)
            echo -e "${BLUE}🏭 Stopping Production Environment${NC}"
            # Try Kubernetes first, then Docker
            if command -v kubectl > /dev/null 2>&1 && kubectl get namespace snapchallan > /dev/null 2>&1; then
                stop_kubernetes
            else
                stop_docker_compose "docker-compose.prod.yml" "production"
                if [[ ! -f "docker-compose.prod.yml" ]]; then
                    stop_docker_compose "docker-compose.yml" "production"
                fi
            fi
            ;;
        test)
            echo -e "${BLUE}🧪 Stopping Test Environment${NC}"
            stop_docker_compose "docker-compose.test.yml" "test"
            ;;
        all)
            echo -e "${BLUE}🌐 Stopping All Environments${NC}"
            stop_docker_compose "docker-compose.yml" "development"
            stop_docker_compose "docker-compose.prod.yml" "production"
            stop_docker_compose "docker-compose.test.yml" "test"
            stop_kubernetes
            ;;
    esac
}

# Main execution
if [[ "$FORCE" == true ]]; then
    echo -e "${RED}🔨 Force stop mode enabled${NC}"
    kill_processes
fi

# Stop the specified environment
stop_environment "$ENVIRONMENT"

# Additional cleanup for 'all' environment or if requested
if [[ "$ENVIRONMENT" == "all" ]] || [[ "$REMOVE_VOLUMES" == true ]] || [[ "$REMOVE_IMAGES" == true ]]; then
    cleanup_docker
fi

# Show remaining resources
echo ""
echo -e "${BLUE}📊 Remaining Docker Resources:${NC}"
echo -e "${YELLOW}Containers:${NC}"
docker ps -a --filter "label=com.docker.compose.project=snapchallan" || echo "None"

echo -e "${YELLOW}Images:${NC}"
docker images | grep snapchallan || echo "None"

echo -e "${YELLOW}Volumes:${NC}"
docker volume ls | grep snapchallan || echo "None"

echo -e "${YELLOW}Networks:${NC}"
docker network ls | grep snapchallan || echo "None"

# Final status
echo ""
if [[ "$ENVIRONMENT" == "all" ]]; then
    echo -e "${GREEN}🎉 All SnapChallan services stopped successfully!${NC}"
else
    echo -e "${GREEN}🎉 SnapChallan $ENVIRONMENT environment stopped successfully!${NC}"
fi

echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo -e "  Start services: ./scripts/start.sh"
echo -e "  View logs:      ./scripts/logs.sh"
echo -e "  Full cleanup:   ./scripts/stop.sh -e all -v -i"
echo ""

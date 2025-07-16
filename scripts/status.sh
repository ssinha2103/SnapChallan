#!/bin/bash

# SnapChallan - Status Script
# This script shows the status of SnapChallan services

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
DETAILED=false
HEALTH_CHECK=false

# Help function
show_help() {
    echo -e "${BLUE}SnapChallan Status Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --env ENV        Environment to check (development|production|all)"
    echo "  -d, --detailed       Show detailed information"
    echo "  -c, --health         Perform health checks"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   # Show basic status"
    echo "  $0 -d                # Show detailed status"
    echo "  $0 -c                # Perform health checks"
    echo "  $0 -e production -d  # Show detailed production status"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -d|--detailed)
            DETAILED=true
            shift
            ;;
        -c|--health)
            HEALTH_CHECK=true
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
if [[ ! "$ENVIRONMENT" =~ ^(development|production|all)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Use: development, production, or all${NC}"
    exit 1
fi

echo -e "${BLUE}📊 SnapChallan Status Report${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo -e "${YELLOW}Timestamp: $(date)${NC}"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Function to check Docker status
check_docker_status() {
    local compose_file="$1"
    local env_name="$2"
    
    echo -e "${BLUE}🐳 Docker Status - $env_name${NC}"
    
    if [[ ! -f "$compose_file" ]]; then
        echo -e "${RED}❌ Compose file $compose_file not found${NC}"
        return 1
    fi
    
    # Check if services are running
    if docker-compose -f "$compose_file" ps | grep -q "Up"; then
        echo -e "${GREEN}✅ Services are running${NC}"
        
        if [[ "$DETAILED" == true ]]; then
            echo ""
            docker-compose -f "$compose_file" ps
            echo ""
            
            # Show resource usage
            echo -e "${YELLOW}📈 Resource Usage:${NC}"
            docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.PIDs}}" $(docker-compose -f "$compose_file" ps -q) 2>/dev/null || echo "Unable to get stats"
        else
            docker-compose -f "$compose_file" ps --services --filter "status=running"
        fi
    else
        echo -e "${RED}❌ No services running${NC}"
        if [[ "$DETAILED" == true ]]; then
            docker-compose -f "$compose_file" ps
        fi
    fi
    echo ""
}

# Function to check Kubernetes status
check_kubernetes_status() {
    echo -e "${BLUE}☸️  Kubernetes Status${NC}"
    
    if ! command -v kubectl > /dev/null 2>&1; then
        echo -e "${RED}❌ kubectl not available${NC}"
        return 1
    fi
    
    if ! kubectl get namespace snapchallan > /dev/null 2>&1; then
        echo -e "${RED}❌ SnapChallan namespace not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ SnapChallan namespace exists${NC}"
    
    # Check pods
    echo -e "${YELLOW}📦 Pods:${NC}"
    kubectl get pods -n snapchallan
    echo ""
    
    # Check services
    echo -e "${YELLOW}🌐 Services:${NC}"
    kubectl get services -n snapchallan
    echo ""
    
    if [[ "$DETAILED" == true ]]; then
        # Check deployments
        echo -e "${YELLOW}🚀 Deployments:${NC}"
        kubectl get deployments -n snapchallan
        echo ""
        
        # Check ingress
        echo -e "${YELLOW}🌍 Ingress:${NC}"
        kubectl get ingress -n snapchallan 2>/dev/null || echo "No ingress found"
        echo ""
        
        # Check persistent volumes
        echo -e "${YELLOW}💾 Persistent Volumes:${NC}"
        kubectl get pvc -n snapchallan 2>/dev/null || echo "No PVCs found"
        echo ""
    fi
}

# Function to perform health checks
perform_health_checks() {
    echo -e "${BLUE}🏥 Health Checks${NC}"
    
    local services=(
        "backend:http://localhost:8000/health/"
        "ai:http://localhost:8001/health/"
        "frontend:http://localhost:8000/"
    )
    
    for service_info in "${services[@]}"; do
        local service=$(echo "$service_info" | cut -d: -f1)
        local url=$(echo "$service_info" | cut -d: -f2-)
        
        echo -n -e "${YELLOW}Checking $service... ${NC}"
        
        if curl -f -s --max-time 10 "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Healthy${NC}"
        else
            echo -e "${RED}❌ Unhealthy${NC}"
            
            if [[ "$DETAILED" == true ]]; then
                echo -e "  ${RED}Failed to connect to $url${NC}"
            fi
        fi
    done
    echo ""
}

# Function to check database connectivity
check_database_status() {
    echo -e "${BLUE}🗄️  Database Status${NC}"
    
    # Check MongoDB
    echo -n -e "${YELLOW}MongoDB... ${NC}"
    if docker exec snapchallan_mongodb_1 mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Connected${NC}"
        if [[ "$DETAILED" == true ]]; then
            local db_status=$(docker exec snapchallan_mongodb_1 mongosh --quiet --eval "JSON.stringify(db.adminCommand('serverStatus'))" 2>/dev/null | jq -r '.uptime' 2>/dev/null || echo "Unknown")
            echo -e "  ${YELLOW}Uptime: ${db_status}s${NC}"
        fi
    else
        echo -e "${RED}❌ Not responding${NC}"
    fi
    
    # Check Redis
    echo -n -e "${YELLOW}Redis... ${NC}"
    if docker exec snapchallan_redis_1 redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Connected${NC}"
        if [[ "$DETAILED" == true ]]; then
            local redis_info=$(docker exec snapchallan_redis_1 redis-cli info server | grep uptime_in_seconds | cut -d: -f2 | tr -d '\r')
            echo -e "  ${YELLOW}Uptime: ${redis_info}s${NC}"
        fi
    else
        echo -e "${RED}❌ Not responding${NC}"
    fi
    echo ""
}

# Function to check system resources
check_system_resources() {
    echo -e "${BLUE}💻 System Resources${NC}"
    
    # CPU Usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | cut -d% -f1 2>/dev/null || echo "N/A")
    echo -e "${YELLOW}CPU Usage: ${cpu_usage}%${NC}"
    
    # Memory Usage
    local memory_info=$(vm_stat | grep "Pages free" | awk '{print $3}' | cut -d. -f1 2>/dev/null || echo "N/A")
    echo -e "${YELLOW}Memory: Available${NC}"
    
    # Disk Usage
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}' 2>/dev/null || echo "N/A")
    echo -e "${YELLOW}Disk Usage: ${disk_usage}${NC}"
    
    # Docker Resources
    if docker info > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker is running${NC}"
        if [[ "$DETAILED" == true ]]; then
            local containers=$(docker ps -q | wc -l | tr -d ' ')
            local images=$(docker images -q | wc -l | tr -d ' ')
            local volumes=$(docker volume ls -q | wc -l | tr -d ' ')
            echo -e "  ${YELLOW}Containers: $containers${NC}"
            echo -e "  ${YELLOW}Images: $images${NC}"
            echo -e "  ${YELLOW}Volumes: $volumes${NC}"
        fi
    else
        echo -e "${RED}❌ Docker is not running${NC}"
    fi
    echo ""
}

# Function to check network connectivity
check_network_status() {
    echo -e "${BLUE}🌐 Network Status${NC}"
    
    # Check if ports are listening
    local ports=("8000" "8001" "27017" "6379")
    
    for port in "${ports[@]}"; do
        echo -n -e "${YELLOW}Port $port... ${NC}"
        if lsof -i :$port > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Listening${NC}"
        else
            echo -e "${RED}❌ Not listening${NC}"
        fi
    done
    echo ""
}

# Function to show service URLs
show_service_urls() {
    echo -e "${BLUE}🔗 Service URLs${NC}"
    
    if [[ "$ENVIRONMENT" == "development" ]] || [[ "$ENVIRONMENT" == "all" ]]; then
        echo -e "${YELLOW}Development Environment:${NC}"
        echo -e "  Frontend (PWA):     http://localhost:8000"
        echo -e "  Backend API:        http://localhost:8000/api"
        echo -e "  AI Service:         http://localhost:8001"
        echo -e "  Grafana:           http://localhost:3000"
        echo -e "  Prometheus:        http://localhost:9090"
        echo ""
    fi
    
    if [[ "$ENVIRONMENT" == "production" ]] || [[ "$ENVIRONMENT" == "all" ]]; then
        if kubectl get ingress -n snapchallan > /dev/null 2>&1; then
            echo -e "${YELLOW}Production Environment:${NC}"
            kubectl get ingress -n snapchallan -o custom-columns=NAME:.metadata.name,HOSTS:.spec.rules[*].host,ADDRESS:.status.loadBalancer.ingress[*].ip
        fi
    fi
}

# Function to show recent logs summary
show_recent_activity() {
    echo -e "${BLUE}📋 Recent Activity${NC}"
    
    # Show container restart count
    if [[ "$ENVIRONMENT" == "development" ]]; then
        local restarts=$(docker-compose ps | grep -v "Exit 0" | grep -c "Restarting\|Exit" 2>/dev/null || echo "0")
        if [[ $restarts -gt 0 ]]; then
            echo -e "${RED}⚠️  $restarts services have issues${NC}"
        else
            echo -e "${GREEN}✅ All services stable${NC}"
        fi
    elif kubectl get namespace snapchallan > /dev/null 2>&1; then
        local pod_issues=$(kubectl get pods -n snapchallan --no-headers | grep -v "Running\|Completed" | wc -l)
        if [[ $pod_issues -gt 0 ]]; then
            echo -e "${RED}⚠️  $pod_issues pods have issues${NC}"
            kubectl get pods -n snapchallan | grep -v "Running\|Completed"
        else
            echo -e "${GREEN}✅ All pods running normally${NC}"
        fi
    fi
    echo ""
}

# Main execution
case $ENVIRONMENT in
    development)
        check_docker_status "docker-compose.yml" "Development"
        if [[ "$HEALTH_CHECK" == true ]]; then
            perform_health_checks
            check_database_status
        fi
        ;;
    production)
        if kubectl get namespace snapchallan > /dev/null 2>&1; then
            check_kubernetes_status
        else
            check_docker_status "docker-compose.prod.yml" "Production"
            if [[ ! -f "docker-compose.prod.yml" ]]; then
                check_docker_status "docker-compose.yml" "Production"
            fi
        fi
        if [[ "$HEALTH_CHECK" == true ]]; then
            perform_health_checks
        fi
        ;;
    all)
        check_docker_status "docker-compose.yml" "Development"
        if kubectl get namespace snapchallan > /dev/null 2>&1; then
            check_kubernetes_status
        fi
        if [[ "$HEALTH_CHECK" == true ]]; then
            perform_health_checks
            check_database_status
        fi
        ;;
esac

if [[ "$DETAILED" == true ]]; then
    check_system_resources
    check_network_status
    show_recent_activity
fi

show_service_urls

echo -e "${YELLOW}📋 Quick Commands:${NC}"
echo -e "  Detailed status:    $0 -d"
echo -e "  Health checks:      $0 -c"
echo -e "  View logs:          ./scripts/logs.sh"
echo -e "  Restart services:   ./scripts/restart.sh"
echo ""

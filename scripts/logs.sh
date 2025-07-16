#!/bin/bash

# SnapChallan - Logs Script
# This script shows logs from SnapChallan services

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
FOLLOW=false
TAIL_LINES=100

# Help function
show_help() {
    echo -e "${BLUE}SnapChallan Logs Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --service NAME   Service to show logs for (backend|ai|frontend|mongodb|redis|all)"
    echo "  -e, --env ENV        Environment (development|production)"
    echo "  -f, --follow         Follow log output (like tail -f)"
    echo "  -n, --lines NUM      Number of lines to show (default: 100)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   # Show last 100 lines from all services"
    echo "  $0 -s backend -f     # Follow backend logs"
    echo "  $0 -s ai -n 50       # Show last 50 lines from AI service"
    echo "  $0 -e production -f  # Follow production logs"
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
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -n|--lines)
            TAIL_LINES="$2"
            shift 2
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

echo -e "${BLUE}📋 SnapChallan Logs${NC}"
echo -e "${YELLOW}Service: $SERVICE${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo -e "${YELLOW}Lines: $TAIL_LINES${NC}"
if [[ "$FOLLOW" == true ]]; then
    echo -e "${YELLOW}Mode: Following (Press Ctrl+C to exit)${NC}"
fi
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Function to show Docker Compose logs
show_docker_logs() {
    local compose_file="$1"
    local service_name="$2"
    
    if [[ ! -f "$compose_file" ]]; then
        echo -e "${RED}❌ Compose file $compose_file not found${NC}"
        return 1
    fi
    
    local cmd="docker-compose -f $compose_file logs"
    
    if [[ "$FOLLOW" == true ]]; then
        cmd="$cmd -f"
    fi
    
    cmd="$cmd --tail=$TAIL_LINES"
    
    if [[ "$service_name" != "all" ]]; then
        cmd="$cmd $service_name"
    fi
    
    echo -e "${YELLOW}🐳 Docker Compose Logs:${NC}"
    eval $cmd
}

# Function to show Kubernetes logs
show_kubernetes_logs() {
    local service_name="$1"
    
    if ! command -v kubectl > /dev/null 2>&1; then
        echo -e "${RED}❌ kubectl not available${NC}"
        return 1
    fi
    
    if ! kubectl get namespace snapchallan > /dev/null 2>&1; then
        echo -e "${RED}❌ SnapChallan namespace not found in Kubernetes${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}☸️  Kubernetes Logs:${NC}"
    
    if [[ "$service_name" == "all" ]]; then
        # Show logs from all pods
        local pods=$(kubectl get pods -n snapchallan -o jsonpath='{.items[*].metadata.name}')
        for pod in $pods; do
            echo -e "${BLUE}📦 Pod: $pod${NC}"
            local cmd="kubectl logs -n snapchallan $pod --tail=$TAIL_LINES"
            if [[ "$FOLLOW" == true ]]; then
                cmd="$cmd -f"
            fi
            eval $cmd
            echo ""
        done
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
        
        local cmd="kubectl logs -n snapchallan deployment/$deployment --tail=$TAIL_LINES"
        if [[ "$FOLLOW" == true ]]; then
            cmd="$cmd -f"
        fi
        eval $cmd
    fi
}

# Function to show service-specific logs
show_service_logs() {
    echo -e "${BLUE}🔍 Showing logs for: $SERVICE${NC}"
    echo ""
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        show_docker_logs "docker-compose.yml" "$SERVICE"
    elif [[ "$ENVIRONMENT" == "production" ]]; then
        # Try Kubernetes first, then Docker
        if kubectl get namespace snapchallan > /dev/null 2>&1; then
            show_kubernetes_logs "$SERVICE"
        else
            # Try production compose file, fallback to regular
            if [[ -f "docker-compose.prod.yml" ]]; then
                show_docker_logs "docker-compose.prod.yml" "$SERVICE"
            else
                show_docker_logs "docker-compose.yml" "$SERVICE"
            fi
        fi
    fi
}

# Function to show aggregated logs with timestamps
show_aggregated_logs() {
    echo -e "${BLUE}📊 Aggregated Logs with Timestamps${NC}"
    echo ""
    
    local temp_file="/tmp/snapchallan_logs_$(date +%s).log"
    
    # Collect logs from all services
    if [[ "$ENVIRONMENT" == "development" ]]; then
        docker-compose logs --no-color --timestamps --tail=$TAIL_LINES > "$temp_file" 2>/dev/null || true
    elif kubectl get namespace snapchallan > /dev/null 2>&1; then
        kubectl logs -n snapchallan --all-containers=true --timestamps --tail=$TAIL_LINES > "$temp_file" 2>/dev/null || true
    fi
    
    if [[ -f "$temp_file" && -s "$temp_file" ]]; then
        if [[ "$FOLLOW" == true ]]; then
            tail -f "$temp_file"
        else
            cat "$temp_file"
        fi
        rm -f "$temp_file"
    else
        echo -e "${YELLOW}⚠️  No logs found or services not running${NC}"
    fi
}

# Function to show log summary
show_log_summary() {
    echo -e "${BLUE}📈 Log Summary${NC}"
    echo ""
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        if docker-compose ps | grep -q "Up"; then
            echo -e "${GREEN}✅ Services running:${NC}"
            docker-compose ps
        else
            echo -e "${RED}❌ No services running${NC}"
        fi
    elif kubectl get namespace snapchallan > /dev/null 2>&1; then
        echo -e "${GREEN}☸️  Kubernetes pods:${NC}"
        kubectl get pods -n snapchallan
    fi
    
    echo ""
}

# Function to analyze error logs
analyze_errors() {
    echo -e "${BLUE}🔍 Error Analysis${NC}"
    echo ""
    
    local error_patterns=(
        "ERROR"
        "CRITICAL"
        "FATAL"
        "Exception"
        "Traceback"
        "failed"
        "error"
    )
    
    local temp_file="/tmp/snapchallan_errors_$(date +%s).log"
    
    # Collect recent logs
    if [[ "$ENVIRONMENT" == "development" ]]; then
        docker-compose logs --no-color --tail=1000 > "$temp_file" 2>/dev/null || true
    elif kubectl get namespace snapchallan > /dev/null 2>&1; then
        kubectl logs -n snapchallan --all-containers=true --tail=1000 > "$temp_file" 2>/dev/null || true
    fi
    
    if [[ -f "$temp_file" && -s "$temp_file" ]]; then
        for pattern in "${error_patterns[@]}"; do
            local count=$(grep -i "$pattern" "$temp_file" | wc -l)
            if [[ $count -gt 0 ]]; then
                echo -e "${RED}❌ $pattern: $count occurrences${NC}"
                grep -i "$pattern" "$temp_file" | tail -5
                echo ""
            fi
        done
        rm -f "$temp_file"
    else
        echo -e "${YELLOW}⚠️  No logs available for analysis${NC}"
    fi
}

# Main execution
case $SERVICE in
    all)
        show_log_summary
        if [[ "$FOLLOW" == true ]]; then
            show_aggregated_logs
        else
            show_service_logs
            echo ""
            analyze_errors
        fi
        ;;
    *)
        show_service_logs
        ;;
esac

echo ""
echo -e "${YELLOW}📋 Useful Commands:${NC}"
echo -e "  Follow all logs:    $0 -f"
echo -e "  Backend logs:       $0 -s backend"
echo -e "  AI service logs:    $0 -s ai"
echo -e "  Error analysis:     $0 -s all"
echo -e "  Production logs:    $0 -e production"
echo ""

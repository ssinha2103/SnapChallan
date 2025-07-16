#!/bin/bash

# SnapChallan - Development Helper Script
# This script provides quick development utilities

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

# Help function
show_help() {
    echo -e "${BLUE}SnapChallan Development Helper${NC}"
    echo ""
    echo "Usage: $0 COMMAND [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  init                 Initialize development environment"
    echo "  setup                Setup project dependencies"
    echo "  test                 Run test suite"
    echo "  lint                 Run code linting"
    echo "  format               Format code"
    echo "  migrate              Run database migrations"
    echo "  seed                 Seed database with test data"
    echo "  shell                Open Django shell"
    echo "  dbshell              Open database shell"
    echo "  backup               Backup database"
    echo "  restore FILE         Restore database from backup"
    echo "  clean                Clean up development environment"
    echo ""
    echo "Examples:"
    echo "  $0 init              # Initialize everything"
    echo "  $0 test              # Run all tests"
    echo "  $0 migrate           # Run migrations"
    echo "  $0 backup            # Backup database"
    echo ""
}

# Parse command
if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

COMMAND="$1"
shift

echo -e "${BLUE}🛠️  SnapChallan Development Helper${NC}"
echo -e "${YELLOW}Command: $COMMAND${NC}"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker not found. Please install Docker.${NC}"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker Compose not found. Please install Docker Compose.${NC}"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running. Please start Docker.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Function to initialize development environment
init_environment() {
    echo -e "${BLUE}🚀 Initializing Development Environment${NC}"
    
    check_prerequisites
    
    # Create environment file
    if [[ ! -f ".env" ]]; then
        echo -e "${YELLOW}📝 Creating .env file...${NC}"
        cp .env.example .env
        echo -e "${GREEN}✅ .env file created${NC}"
        echo -e "${YELLOW}💡 Please edit .env file with your configuration${NC}"
    else
        echo -e "${GREEN}✅ .env file already exists${NC}"
    fi
    
    # Create necessary directories
    mkdir -p logs backups
    
    # Start services
    echo -e "${YELLOW}🐳 Starting services...${NC}"
    docker-compose up -d
    
    # Wait for services
    echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
    sleep 30
    
    # Run migrations
    migrate_database
    
    # Create admin user
    create_admin_user
    
    echo -e "${GREEN}🎉 Development environment initialized!${NC}"
}

# Function to setup project dependencies
setup_dependencies() {
    echo -e "${BLUE}📦 Setting Up Dependencies${NC}"
    
    # Backend dependencies
    echo -e "${YELLOW}🐍 Installing backend dependencies...${NC}"
    docker-compose exec backend pip install -r requirements.txt
    
    # Frontend dependencies (if package.json exists)
    if [[ -f "frontend/package.json" ]]; then
        echo -e "${YELLOW}📦 Installing frontend dependencies...${NC}"
        cd frontend && npm install && cd ..
    fi
    
    echo -e "${GREEN}✅ Dependencies setup complete${NC}"
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}🧪 Running Test Suite${NC}"
    
    # Backend tests
    echo -e "${YELLOW}🐍 Running backend tests...${NC}"
    docker-compose exec backend python manage.py test
    
    # Coverage report
    echo -e "${YELLOW}📊 Generating coverage report...${NC}"
    docker-compose exec backend coverage run --source='.' manage.py test
    docker-compose exec backend coverage report
    docker-compose exec backend coverage html
    
    # Frontend tests (if they exist)
    if [[ -f "frontend/package.json" ]]; then
        echo -e "${YELLOW}🌐 Running frontend tests...${NC}"
        cd frontend && npm test && cd ..
    fi
    
    # AI service tests
    echo -e "${YELLOW}🤖 Running AI service tests...${NC}"
    docker-compose exec ai python -m pytest tests/ -v
    
    echo -e "${GREEN}✅ All tests completed${NC}"
}

# Function to run linting
run_linting() {
    echo -e "${BLUE}🔍 Running Code Linting${NC}"
    
    # Backend linting
    echo -e "${YELLOW}🐍 Linting backend code...${NC}"
    docker-compose exec backend flake8 . --max-line-length=88 --extend-ignore=E203,W503
    docker-compose exec backend black --check .
    docker-compose exec backend isort --check-only .
    
    # Frontend linting (if configured)
    if [[ -f "frontend/.eslintrc.js" ]]; then
        echo -e "${YELLOW}🌐 Linting frontend code...${NC}"
        cd frontend && npm run lint && cd ..
    fi
    
    echo -e "${GREEN}✅ Linting completed${NC}"
}

# Function to format code
format_code() {
    echo -e "${BLUE}✨ Formatting Code${NC}"
    
    # Backend formatting
    echo -e "${YELLOW}🐍 Formatting backend code...${NC}"
    docker-compose exec backend black .
    docker-compose exec backend isort .
    
    # Frontend formatting (if configured)
    if [[ -f "frontend/.prettierrc" ]]; then
        echo -e "${YELLOW}🌐 Formatting frontend code...${NC}"
        cd frontend && npm run format && cd ..
    fi
    
    echo -e "${GREEN}✅ Code formatting completed${NC}"
}

# Function to run database migrations
migrate_database() {
    echo -e "${BLUE}🗄️  Running Database Migrations${NC}"
    
    echo -e "${YELLOW}📝 Creating migrations...${NC}"
    docker-compose exec backend python manage.py makemigrations
    
    echo -e "${YELLOW}⚡ Applying migrations...${NC}"
    docker-compose exec backend python manage.py migrate
    
    echo -e "${GREEN}✅ Migrations completed${NC}"
}

# Function to seed database
seed_database() {
    echo -e "${BLUE}🌱 Seeding Database${NC}"
    
    # Create test data
    echo -e "${YELLOW}📊 Creating test data...${NC}"
    docker-compose exec backend python manage.py loaddata fixtures/test_data.json 2>/dev/null || echo "No fixtures found"
    
    # Create admin user if not exists
    create_admin_user
    
    echo -e "${GREEN}✅ Database seeded${NC}"
}

# Function to create admin user
create_admin_user() {
    echo -e "${YELLOW}👤 Creating admin user...${NC}"
    docker-compose exec backend python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(phone_number='+919999999999').exists():
    admin = User.objects.create_superuser(
        phone_number='+919999999999',
        password='admin123',
        first_name='Admin',
        last_name='User',
        email='admin@snapchallan.com',
        is_verified=True,
        aadhaar_verified=True,
        role='officer'
    )
    print('Admin user created: +919999999999 / admin123')
else:
    print('Admin user already exists')
"
}

# Function to open Django shell
open_shell() {
    echo -e "${BLUE}🐍 Opening Django Shell${NC}"
    docker-compose exec backend python manage.py shell
}

# Function to open database shell
open_dbshell() {
    echo -e "${BLUE}🗄️  Opening Database Shell${NC}"
    docker-compose exec mongodb mongosh snapchallan
}

# Function to backup database
backup_database() {
    echo -e "${BLUE}💾 Backing Up Database${NC}"
    
    local backup_file="backups/snapchallan_backup_$(date +%Y%m%d_%H%M%S)"
    
    echo -e "${YELLOW}📦 Creating backup...${NC}"
    docker-compose exec mongodb mongodump --db snapchallan --out /tmp/backup
    docker cp snapchallan_mongodb_1:/tmp/backup/snapchallan "$backup_file"
    
    echo -e "${GREEN}✅ Backup created: $backup_file${NC}"
}

# Function to restore database
restore_database() {
    local backup_file="$1"
    
    if [[ ! -d "$backup_file" ]]; then
        echo -e "${RED}❌ Backup file not found: $backup_file${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔄 Restoring Database${NC}"
    echo -e "${RED}⚠️  This will overwrite the current database!${NC}"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}📤 Copying backup to container...${NC}"
        docker cp "$backup_file" snapchallan_mongodb_1:/tmp/restore_backup
        
        echo -e "${YELLOW}🔄 Restoring database...${NC}"
        docker-compose exec mongodb mongorestore --db snapchallan --drop /tmp/restore_backup
        
        echo -e "${GREEN}✅ Database restored${NC}"
    else
        echo -e "${YELLOW}Operation cancelled${NC}"
    fi
}

# Function to clean up development environment
clean_environment() {
    echo -e "${BLUE}🧹 Cleaning Development Environment${NC}"
    
    echo -e "${RED}⚠️  This will remove all containers, volumes, and data!${NC}"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🛑 Stopping services...${NC}"
        docker-compose down -v
        
        echo -e "${YELLOW}🗑️  Removing images...${NC}"
        docker-compose down --rmi all
        
        echo -e "${YELLOW}🧹 Cleaning Docker system...${NC}"
        docker system prune -f
        
        echo -e "${YELLOW}📁 Removing log files...${NC}"
        rm -rf logs/* backups/*
        
        echo -e "${GREEN}✅ Environment cleaned${NC}"
    else
        echo -e "${YELLOW}Operation cancelled${NC}"
    fi
}

# Main command execution
case $COMMAND in
    init)
        init_environment
        ;;
    setup)
        setup_dependencies
        ;;
    test)
        run_tests
        ;;
    lint)
        run_linting
        ;;
    format)
        format_code
        ;;
    migrate)
        migrate_database
        ;;
    seed)
        seed_database
        ;;
    shell)
        open_shell
        ;;
    dbshell)
        open_dbshell
        ;;
    backup)
        backup_database
        ;;
    restore)
        if [[ $# -eq 0 ]]; then
            echo -e "${RED}❌ Please specify backup file to restore${NC}"
            exit 1
        fi
        restore_database "$1"
        ;;
    clean)
        clean_environment
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac

echo -e "${GREEN}🎉 Operation completed successfully!${NC}"

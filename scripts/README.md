# SnapChallan Scripts

This directory contains utility scripts for managing the SnapChallan platform.

## Available Scripts

### 🚀 `start.sh` - Start Services
Start SnapChallan services in different environments.

```bash
# Start development environment
./scripts/start.sh

# Start production environment  
./scripts/start.sh -e production -d

# Build and start with custom options
./scripts/start.sh -b -d
```

**Options:**
- `-e, --env ENV`: Environment (development|production|test)
- `-d, --detached`: Run in background
- `-b, --build`: Build images before starting
- `-h, --help`: Show help

### 🛑 `stop.sh` - Stop Services
Stop SnapChallan services and cleanup resources.

```bash
# Stop development services
./scripts/stop.sh

# Stop and remove volumes (WARNING: Data loss!)
./scripts/stop.sh -v

# Stop everything and cleanup
./scripts/stop.sh -e all -v -i
```

**Options:**
- `-e, --env ENV`: Environment to stop (development|production|test|all)
- `-v, --volumes`: Remove volumes (destroys data!)
- `-i, --images`: Remove Docker images
- `-f, --force`: Force stop (kill containers)

### 🔄 `restart.sh` - Restart Services
Restart specific services or all services.

```bash
# Restart all services
./scripts/restart.sh

# Restart specific service
./scripts/restart.sh -s backend

# Rebuild and restart production
./scripts/restart.sh -e production -b
```

**Options:**
- `-s, --service NAME`: Service to restart (backend|ai|frontend|mongodb|redis|all)
- `-e, --env ENV`: Environment (development|production)
- `-b, --build`: Rebuild before restarting

### 📋 `logs.sh` - View Logs
View and follow logs from SnapChallan services.

```bash
# Show all recent logs
./scripts/logs.sh

# Follow backend logs
./scripts/logs.sh -s backend -f

# Show last 50 lines from AI service
./scripts/logs.sh -s ai -n 50
```

**Options:**
- `-s, --service NAME`: Service logs (backend|ai|frontend|mongodb|redis|all)
- `-e, --env ENV`: Environment (development|production)
- `-f, --follow`: Follow logs (like tail -f)
- `-n, --lines NUM`: Number of lines to show

### 📊 `status.sh` - Check Status
Check the status of SnapChallan services.

```bash
# Basic status check
./scripts/status.sh

# Detailed status with health checks
./scripts/status.sh -d -c

# Production status
./scripts/status.sh -e production
```

**Options:**
- `-e, --env ENV`: Environment (development|production|all)
- `-d, --detailed`: Show detailed information
- `-c, --health`: Perform health checks

### 🛠️ `dev.sh` - Development Helper
Development utilities and shortcuts.

```bash
# Initialize development environment
./scripts/dev.sh init

# Run tests
./scripts/dev.sh test

# Run database migrations
./scripts/dev.sh migrate

# Backup database
./scripts/dev.sh backup
```

**Commands:**
- `init`: Initialize development environment
- `setup`: Setup project dependencies
- `test`: Run test suite
- `lint`: Run code linting
- `format`: Format code
- `migrate`: Run database migrations
- `seed`: Seed database with test data
- `shell`: Open Django shell
- `dbshell`: Open database shell
- `backup`: Backup database
- `restore FILE`: Restore database from backup
- `clean`: Clean up development environment

## Quick Start Guide

### 1. First Time Setup
```bash
# Initialize everything
./scripts/dev.sh init

# Or start manually
./scripts/start.sh
```

### 2. Daily Development
```bash
# Start services
./scripts/start.sh

# Check status
./scripts/status.sh

# View logs
./scripts/logs.sh -f

# Run tests
./scripts/dev.sh test

# Stop when done
./scripts/stop.sh
```

### 3. Production Deployment
```bash
# Start production environment
./scripts/start.sh -e production -d

# Check production status
./scripts/status.sh -e production -c

# View production logs
./scripts/logs.sh -e production -f
```

## Common Workflows

### Development Workflow
```bash
# 1. Start development environment
./scripts/start.sh

# 2. Make code changes...

# 3. Run tests
./scripts/dev.sh test

# 4. Check logs if needed
./scripts/logs.sh -s backend

# 5. Restart specific service if needed
./scripts/restart.sh -s backend

# 6. Stop when done
./scripts/stop.sh
```

### Database Management
```bash
# Run migrations
./scripts/dev.sh migrate

# Backup database
./scripts/dev.sh backup

# Restore from backup
./scripts/dev.sh restore backups/snapchallan_backup_20240715_143000

# Open database shell
./scripts/dev.sh dbshell

# Seed with test data
./scripts/dev.sh seed
```

### Debugging
```bash
# Check service status
./scripts/status.sh -d

# Follow all logs
./scripts/logs.sh -f

# Check specific service
./scripts/logs.sh -s backend -f

# Health checks
./scripts/status.sh -c

# Open Django shell
./scripts/dev.sh shell
```

### Production Management
```bash
# Deploy to production
./scripts/start.sh -e production -d

# Monitor production
./scripts/status.sh -e production -d

# View production logs
./scripts/logs.sh -e production -f

# Restart production service
./scripts/restart.sh -e production -s backend

# Backup production data
./scripts/dev.sh backup
```

## Environment Variables

Scripts read configuration from:
- `.env` (development)
- `.env.production` (production)
- `.env.test` (testing)

## Service Names

Available service names for scripts:
- `backend`: Django REST API
- `ai`: FastAPI AI service
- `frontend`: Static file server (if applicable)
- `mongodb`: MongoDB database
- `redis`: Redis cache
- `nginx`: Reverse proxy (production)
- `all`: All services

## Script Features

### Color Output
All scripts use colored output for better readability:
- 🔵 Blue: Information
- 🟡 Yellow: Warnings/Progress
- 🟢 Green: Success
- 🔴 Red: Errors

### Error Handling
- Scripts exit on any error (`set -e`)
- Proper error messages with suggestions
- Validation of parameters and prerequisites

### Health Checks
- Automatic health checking after operations
- Service availability verification
- Database connectivity checks

### Logging
- Detailed operation logging
- Timestamp information
- Progress indicators

## Troubleshooting

### Common Issues

1. **Docker not running**
   ```bash
   # Start Docker and try again
   ./scripts/start.sh
   ```

2. **Port already in use**
   ```bash
   # Stop conflicting services
   ./scripts/stop.sh -f
   ```

3. **Permission denied**
   ```bash
   # Make scripts executable
   chmod +x scripts/*.sh
   ```

4. **Services not starting**
   ```bash
   # Check status and logs
   ./scripts/status.sh -d
   ./scripts/logs.sh -f
   ```

### Getting Help

Each script has a help option:
```bash
./scripts/start.sh --help
./scripts/stop.sh --help
./scripts/dev.sh --help
```

## Script Dependencies

### Required Tools
- **Docker**: Container runtime
- **Docker Compose**: Multi-container orchestration
- **curl**: Health checking
- **kubectl**: Kubernetes management (for production)

### Optional Tools
- **jq**: JSON processing
- **lsof**: Port checking
- **mongosh**: MongoDB shell

All scripts check for required dependencies and provide helpful error messages if tools are missing.

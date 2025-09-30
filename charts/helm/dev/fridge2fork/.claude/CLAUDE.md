# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Helm umbrella chart for the Fridge2Fork application deployment on Kubernetes. The chart orchestrates multiple microservices including database, scraping service, admin API, and main server API.

## Chart Architecture

### Umbrella Chart Structure
- **Parent chart**: `fridge2fork` - orchestrates all sub-charts
- **Sub-charts**:
  - `database`: PostgreSQL with Bitnami chart dependency
  - `scrape`: Data scraping service with migration jobs
  - `admin`: Admin FastAPI service
  - `server`: Main FastAPI backend service

### Key Dependencies
- All services depend on `fridge2fork-db-credentials` Kubernetes secret
- Server and admin services use Alembic for database migrations
- Scrape service includes separate Alembic and CSV migration jobs

## Common Development Commands

### Chart Management
```bash
# Install/upgrade the chart
helm upgrade --install fridge2fork . -n default --create-namespace

# Install with specific values
helm upgrade --install fridge2fork . -n default -f values.yaml

# Dry-run to validate templates
helm install fridge2fork . --dry-run --debug -n default

# Template rendering (no cluster needed)
helm template fridge2fork . -n default

# Uninstall
helm uninstall fridge2fork -n default
```

### Chart Dependencies
```bash
# Update chart dependencies (database chart)
helm dependency update

# Build dependencies
helm dependency build
```

### Debugging
```bash
# Check generated manifests
helm get manifest fridge2fork -n default

# Check values
helm get values fridge2fork -n default

# Validate chart structure
helm lint .
```

### Migration Management
```bash
# Deploy migration jobs using helper script
./backup/migration-scripts/deploy-migration.sh default . ./backup/migration-scripts/migration-values.yaml

# Check migration job status
kubectl get jobs -l app.kubernetes.io/component=migration -n default

# View migration logs (Alembic)
kubectl logs -f job/fridge2fork-migration-<timestamp> -c alembic-migration -n default

# View migration logs (CSV)
kubectl logs -f job/fridge2fork-migration-<timestamp> -c csv-migration -n default

# Clean up completed jobs
kubectl delete jobs -l app.kubernetes.io/component=migration -n default
```

## Architecture Details

### Database Secret Requirements
All services require `fridge2fork-db-credentials` secret with:
- `POSTGRES_SERVER`
- `POSTGRES_PORT`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`

### Migration Strategy
1. **Alembic migrations**:
   - Server/Admin: Run in init containers before main application starts
   - Scrape: Run in initContainer before CSV migration (`scrape.initContainer.enabled`)
2. **CSV migrations**:
   - **Primary method**: Main container of scrape Job (`/app/datas/*.csv` → DB)
   - Run after Alembic schema initialization completes
   - Controlled by `scrape.migration.config.RUN_ONCE=true` to prevent duplicate runs
   - **Alternative**: Separate Job (`scrape.migration.csvMigration.enabled`) for independent execution
3. **Job lifecycle**: Migrations use Kubernetes Jobs with configurable TTL and backoff limits

### Service Configuration Pattern
Each sub-chart follows a consistent structure:
- ConfigMap for application settings
- Secret reference for DB credentials
- ServiceAccount with RBAC
- Security contexts (non-root, read-only filesystem)
- Optional HPA for auto-scaling
- Optional health checks (disabled by default)

### Image Tagging Convention
- Images use SHA-based tags: `sha-<commit-hash>`
- Examples: `sha-026d2dc8`, `sha-81534cb1`
- Ensures immutable deployments and precise version control

## Values Override Strategy

### Parent values.yaml controls:
- All sub-chart enable/disable flags
- Image repositories and tags for all services
- Resource limits and requests
- Database configuration

### Sub-chart values.yaml:
- Service-specific defaults
- Template-specific configurations
- Can be overridden from parent chart

## Important Template Patterns

### Init Containers
- **Server/Admin**: Optional Alembic init containers run schema migrations before main container starts (controlled by `initContainer.enabled`)
- **Scrape Job**: Alembic init container runs schema migrations before CSV data import (controlled by `initContainer.enabled`)
  - initContainer: Executes `alembic upgrade head` to initialize database schema
  - main container: Executes `python -m app.migration.csv_migration` to import CSV data from `/app/datas/*.csv`
  - Configured via `scrape.migration.config.RUN_ONCE` to prevent duplicate executions
  - Configurable via `scrape.migration.config.MAX_RECORDS` for testing (0 = all records)

### Job Templates
Scrape chart includes multiple job types:
- `job.yaml`: Regular scraping job (CronJob-ready)
- `alembic-job.yaml`: Schema migration
- `migration-job.yaml`: Combined migration job
- `csv-migration-job.yaml`: Data import job

### Security Contexts
All workloads use restrictive security contexts:
- Non-root user (UID 1000)
- Read-only root filesystem
- Drop all capabilities
- fsGroup 2000 for volume permissions

## Working with This Chart

### Adding a New Service
1. Create new sub-chart in `charts/` directory
2. Add dependency in `Chart.yaml`
3. Add service configuration in parent `values.yaml`
4. Follow existing patterns for ConfigMap, Secret, ServiceAccount

### Modifying Service Configuration
1. Check if the value exists in parent `values.yaml` first
2. For service-specific changes, modify sub-chart's `values.yaml`
3. Validate with `helm template` before applying

### Testing Changes
1. Use `helm template` to validate syntax
2. Use `helm lint` to check for issues
3. Use `--dry-run --debug` for pre-deployment validation
4. Test in development namespace first

## Namespace Convention
- Development environment uses `default` namespace
- Production would use separate namespace (not defined in this chart)
- Migration scripts accept namespace as first argument
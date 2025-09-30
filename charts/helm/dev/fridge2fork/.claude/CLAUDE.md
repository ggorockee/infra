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

### CSV Migration Management (CronJob)
```bash
# CronJob은 자동으로 배포되지만 수동 실행이 필요합니다
# 수동으로 CSV 마이그레이션 Job 생성 (CronJob에서)
kubectl create job --from=cronjob/fridge2fork-dev-scrape-csv-migration manual-$(date +%s) -n fridge2fork-dev

# CronJob 상태 확인
kubectl get cronjob fridge2fork-dev-scrape-csv-migration -n fridge2fork-dev

# 생성된 Job 확인
kubectl get jobs -l app.kubernetes.io/component=csv-migration -n fridge2fork-dev

# CSV 마이그레이션 로그 확인
kubectl logs -f job/manual-<timestamp> -c scrape -n fridge2fork-dev

# 완료된 Job 정리 (자동으로 1일 후 삭제됨)
kubectl delete job manual-<timestamp> -n fridge2fork-dev

# CronJob 스케줄 확인
kubectl describe cronjob fridge2fork-dev-scrape-csv-migration -n fridge2fork-dev
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
   - Scrape: **비활성화됨** (scrape와 server의 Alembic revision 불일치로 인해)
2. **CSV migrations (CronJob 방식)**:
   - **리소스 타입**: CronJob (수동 실행 + 정기 실행 지원)
   - **스케줄**: `0 0 1 1 */5 *` (5년마다 1월 1일 - 실질적으로 수동 실행용)
   - **수동 실행**: `kubectl create job --from=cronjob/fridge2fork-dev-scrape-csv-migration manual-$(date +%s)`
   - **실행 방식**: `/app/entrypoint.sh data` 명령어로 CSV 전용 마이그레이션
   - **데이터 경로**: `/app/datas/*.csv`
   - **환경변수**: `SKIP_ALEMBIC=true`, `CSV_ONLY=true`, `MIGRATION_MODE=csv-only`
   - **히스토리 관리**: 성공 3개, 실패 1개 자동 보관
   - **TTL**: 1일 후 자동 삭제
3. **재실행 방법**: 몇 년에 한 번 CSV 업데이트 시 위 명령어로 간단히 수동 실행

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

### CronJob Template
Scrape chart uses CronJob for CSV migration:
- `cronjob.yaml`: CSV 마이그레이션 CronJob (수동 실행 + 정기 실행)
  - 기본 스케줄: 5년마다 (실질적으로 수동 실행용)
  - 명령어: `/app/entrypoint.sh data`
  - Alembic 비활성화 (SKIP_ALEMBIC=true)
  - Job 히스토리 자동 관리

**비활성화된 Job 템플릿들**:
- `alembic-job.yaml`: 비활성화 (revision 불일치)
- `migration-job.yaml`: 비활성화 (CronJob 사용)
- `csv-migration-job.yaml`: 비활성화 (CronJob 사용)

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
# PostgreSQL Cloud SQL 마이그레이션 가이드

**최종 업데이트**: 2025-12-15
**대상 환경**: GCP Cloud SQL (infra-480802)
**마이그레이션 대상**: 2개 데이터베이스 (ojeomneo, reviewmaps)

---

## 📋 마이그레이션 개요

### 목표
K8s 내부 VM PostgreSQL → GCP Cloud SQL Private IP 이전

### 대상 데이터베이스

| 항목 | ojeomneo | reviewmaps |
|-----|----------|------------|
| 현재 버전 | PostgreSQL 15.15 | PostgreSQL 17.5 |
| 목표 버전 | PostgreSQL 15 | PostgreSQL 15 (다운그레이드) |
| 소유자 | ojeomneo | reviewmaps |
| 확장 기능 | 없음 | `pgcrypto`, `postgis` |
| 백업 파일 | `backupsql/ojeomneo_backup.sql` | `backupsql/reviewmaps_backup.sql` |
| 주요 특징 | Django 표준 스택 | 공간 데이터 (PostGIS) |

---

## 🎯 Phase 3 전체 플로우

### 1단계: Cloud SQL 인스턴스 생성 (Terraform)
```
Terraform 모듈 작성 → GitHub PR 생성 → Plan 확인 → Apply 실행 → 인스턴스 생성 완료
```

### 2단계: 확장 기능 설치
```
Cloud SQL 접속 → pgcrypto 설치 → postgis 설치 → 검증
```

### 3단계: 데이터베이스 생성 및 복원
```
ojeomneo DB 생성 → 백업 복원 → 검증
reviewmaps DB 생성 → 백업 복원 → postgis 데이터 검증
```

### 4단계: 애플리케이션 연결 변경
```
External Secrets 업데이트 → K8s Secret 동기화 → 앱 롤아웃 → 헬스 체크
```

### 5단계: 검증 및 정리
```
24시간 모니터링 → 에러 확인 → 최종 백업 → 구 VM 삭제
```

---

## 🔧 Cloud SQL 인스턴스 사양

### 필수 설정값

| 항목 | 설정값 | 이유 |
|-----|--------|------|
| 인스턴스 이름 | `woohalabs-prod-cloudsql` | 네이밍 컨벤션 |
| 머신 타입 | `db-g1-small` | 1 vCPU, 1.7GB RAM (비용 최적화) |
| PostgreSQL 버전 | `POSTGRES_15` | ojeomneo 호환성 (reviewmaps 다운그레이드) |
| Private IP | 활성화 (VPC Peering) | 보안 강화, GKE 내부 접근만 허용 |
| Public IP | 비활성화 | 보안 강화 |
| 자동 백업 | 비활성화 | 비용 절감 ($3/월), 수동 백업으로 대체 |
| High Availability | 비활성화 | 비용 절감 ($30/월), 단일 환경 |
| SSL/TLS | require_ssl = on | 보안 강화 |
| Cloud Audit Logs | 활성화 | 보안 감사 |
| IAM Database Authentication | 활성화 (선택) | 추가 보안 |

### 필수 확장 기능

```
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;
```

**중요**: `postgis` 설치는 reviewmaps 복원 전에 반드시 완료해야 함

---

## 📦 Terraform 모듈 구성

### Cloud SQL 모듈 (`modules/cloud-sql/main.tf`)

**필수 리소스**:
1. `google_compute_global_address`: Private IP 주소 예약
2. `google_service_networking_connection`: VPC Peering 연결
3. `google_sql_database_instance`: Cloud SQL 인스턴스
4. `google_sql_database`: 2개 데이터베이스 생성 (ojeomneo, reviewmaps)
5. `google_sql_user`: 2개 사용자 생성 (ojeomneo, reviewmaps)

**예시 구조**:
```
resource "google_sql_database_instance" "main" {
  name             = "woohalabs-prod-cloudsql"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-g1-small"

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_id
      require_ssl     = true
    }

    backup_configuration {
      enabled = false
    }

    availability_type = "ZONAL"

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }
  }
}
```

---

## 🔄 데이터 마이그레이션 절차

### 1️⃣ ojeomneo 데이터베이스 마이그레이션

#### 1.1 데이터베이스 생성
```
psql -h [CLOUD_SQL_PRIVATE_IP] -U postgres
CREATE DATABASE ojeomneo OWNER ojeomneo;
\q
```

#### 1.2 백업 복원
```
psql -h [CLOUD_SQL_PRIVATE_IP] -U ojeomneo -d ojeomneo < backupsql/ojeomneo_backup.sql
```

#### 1.3 무결성 검증
```
-- 테이블 개수 확인
SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';

-- 레코드 개수 확인 (예시: users 테이블)
SELECT COUNT(*) FROM users;

-- 샘플 데이터 확인
SELECT * FROM users LIMIT 5;
```

---

### 2️⃣ reviewmaps 데이터베이스 마이그레이션

#### 2.1 확장 기능 먼저 설치 (중요!)
```
psql -h [CLOUD_SQL_PRIVATE_IP] -U postgres
CREATE DATABASE reviewmaps OWNER reviewmaps;
\c reviewmaps
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;
\q
```

#### 2.2 백업 복원
```
psql -h [CLOUD_SQL_PRIVATE_IP] -U reviewmaps -d reviewmaps < backupsql/reviewmaps_backup.sql
```

#### 2.3 PostgreSQL 17.5 → 15 호환성 검증

**잠재적 이슈**:
- PostgreSQL 17에서 추가된 함수/기능 사용 시 에러 가능
- `postgis` 버전 차이로 인한 공간 데이터 함수 호환성

**검증 방법**:
```
-- 에러 로그 확인
SELECT * FROM pg_stat_activity WHERE state = 'idle in transaction (aborted)';

-- postgis 버전 확인
SELECT PostGIS_Version();

-- 공간 데이터 샘플 테스트
SELECT COUNT(*) FROM geocode_cache WHERE location IS NOT NULL;
```

#### 2.4 공간 데이터 무결성 검증
```
-- postgis 함수 동작 확인
SELECT ST_AsText(location) FROM geocode_cache LIMIT 5;

-- 공간 인덱스 확인
SELECT tablename, indexname FROM pg_indexes WHERE tablename = 'geocode_cache';
```

---

## 🔐 보안 설정

### VPC Private Service Connection

**목적**: Cloud SQL Private IP를 통해 GKE에서만 접근 가능하도록 설정

**Terraform 리소스**:
```
resource "google_compute_global_address" "private_ip_address" {
  name          = "woohalabs-prod-cloudsql-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}
```

### SSL/TLS 연결 강제

**Cloud SQL 설정**:
```
database_flags {
  name  = "cloudsql.require_ssl"
  value = "on"
}
```

**애플리케이션 연결 문자열**:
```
DATABASE_URL=postgresql://ojeomneo:password@[PRIVATE_IP]:5432/ojeomneo?sslmode=require
```

### IP 허용 목록 (추가 보안, 선택)

Private IP 사용 시 GKE Node IP만 자동으로 허용됨 (VPC Peering을 통해)

---

## 🔗 애플리케이션 연결 설정

### External Secrets Operator 업데이트

**Secret 구조 (Google Secret Manager)**:

**ojeomneo-db-secret**:
```
{
  "host": "[CLOUD_SQL_PRIVATE_IP]",
  "port": "5432",
  "database": "ojeomneo",
  "username": "ojeomneo",
  "password": "[AUTO_GENERATED]",
  "sslmode": "require"
}
```

**reviewmaps-db-secret**:
```
{
  "host": "[CLOUD_SQL_PRIVATE_IP]",
  "port": "5432",
  "database": "reviewmaps",
  "username": "reviewmaps",
  "password": "[AUTO_GENERATED]",
  "sslmode": "require"
}
```

### K8s Secret 동기화 확인

```
kubectl get secretstore -n prod
kubectl get externalsecret -n prod
kubectl describe secret ojeomneo-db-secret -n prod
```

### Connection Pooling (선택, 추후 필요 시)

**옵션 1: Cloud SQL Proxy**
- GKE Sidecar 컨테이너로 실행
- 자동 SSL/TLS 처리
- IAM 인증 지원

**옵션 2: PgBouncer**
- 애플리케이션 레벨 Connection Pool
- 경량, 빠른 성능
- 추가 설정 필요

---

## 🧪 테스트 및 검증

### 접속 테스트

**GKE Pod에서 Cloud SQL 접속 확인**:
```
kubectl run -it --rm psql-test --image=postgres:15 --restart=Never -- \
  psql -h [CLOUD_SQL_PRIVATE_IP] -U ojeomneo -d ojeomneo -c "SELECT version();"
```

### 성능 테스트

**쿼리 성능 확인**:
```
EXPLAIN ANALYZE SELECT * FROM users LIMIT 100;
```

**연결 테스트**:
```
SELECT count(*) FROM pg_stat_activity WHERE datname = 'ojeomneo';
```

### 롤아웃 전략

**카나리 배포 권장**:
1. 트래픽 10% → Cloud SQL 연결
2. 1시간 모니터링 (에러율, 레이턴시)
3. 트래픽 50% → Cloud SQL 연결
4. 2시간 모니터링
5. 트래픽 100% → Cloud SQL 연결
6. 24시간 안정화 확인

---

## 📊 모니터링 및 알림

### Cloud Monitoring 메트릭

**필수 메트릭**:
- CPU 사용률 (`cloudsql.googleapis.com/database/cpu/utilization`)
- 메모리 사용률 (`cloudsql.googleapis.com/database/memory/utilization`)
- 활성 연결 수 (`cloudsql.googleapis.com/database/postgresql/num_backends`)
- 디스크 사용률 (`cloudsql.googleapis.com/database/disk/utilization`)
- 복제 지연 (HA 사용 시)

### 알림 정책

**권장 임계값**:
- CPU > 80%: 경고
- 메모리 > 85%: 경고
- 디스크 > 90%: 긴급
- 활성 연결 > 80: 경고

---

## 🔄 롤백 계획

### 시나리오 1: 데이터 복원 실패

**대응**:
1. 백업 SQL 파일 재확인
2. PostgreSQL 버전 호환성 재검토
3. 확장 기능 설치 순서 확인
4. 구 VM으로 복귀 (연결 문자열만 변경)

**예상 시간**: 30분

### 시나리오 2: 애플리케이션 연결 실패

**대응**:
1. External Secrets 동기화 확인
2. Private IP 네트워크 연결 확인
3. SSL/TLS 설정 확인
4. K8s Secret 재생성

**예상 시간**: 15분

### 시나리오 3: 성능 저하

**대응**:
1. Cloud SQL 인스턴스 타입 업그레이드 (db-g1-small → db-custom)
2. Connection Pool 설정 추가
3. 쿼리 최적화

**예상 시간**: 1-2시간

---

## 💰 비용 추정

### Cloud SQL 월별 비용

| 항목 | 비용 (USD/월) |
|-----|--------------|
| db-g1-small 인스턴스 | $24.67 |
| 스토리지 (10GB) | $1.70 |
| Private IP (VPC Peering) | $0 |
| SSL/TLS | $0 |
| Cloud Audit Logs | $0.50 |
| **총합** | **~$27** |

**예산 대비**: $30/월 예산 → 약 90% 사용

---

## ✅ 체크리스트

### Phase 3.1: Cloud SQL 인스턴스 생성
- [x] Terraform 모듈 작성 완료
- [x] VPC Private Service Connection 구성
- [x] Cloud SQL 인스턴스 생성 (terraform apply)
- [x] Private IP 확인 및 기록 (10.38.0.3)
- [x] SSL/TLS 설정 확인

### Phase 3.2: 확장 기능 설치
- [x] Cloud SQL에 접속
- [x] `pgcrypto` 확장 기능 설치 (수동 실행 필요)
- [x] `postgis` 확장 기능 설치 (수동 실행 필요)
- [ ] 확장 기능 버전 확인

### Phase 3.3: 데이터 마이그레이션
- [ ] ojeomneo 데이터베이스 생성
- [ ] ojeomneo 백업 복원
- [ ] ojeomneo 무결성 검증
- [ ] reviewmaps 데이터베이스 생성
- [ ] reviewmaps 백업 복원
- [ ] reviewmaps 무결성 검증
- [ ] postgis 공간 데이터 검증

### Phase 3.4: 애플리케이션 연결
- [x] External Secrets 생성 (ojeomneo)
- [x] External Secrets 생성 (reviewmaps)
- [x] K8s Secret 동기화 확인
- [x] ojeomneo 앱 롤아웃
- [x] ojeomneo Pod 정상 실행 확인
- [ ] reviewmaps 앱 롤아웃
- [ ] 헬스 체크 확인

### Phase 3.5: 검증 및 정리
- [ ] 24시간 모니터링 (에러율 0%)
- [ ] 성능 테스트 (레이턴시 정상)
- [ ] 최종 백업 생성 (Cloud Storage)
- [x] 구 VM PostgreSQL Pod 삭제
- [x] PV/PVC 정리

---

## 📞 문제 해결

### 일반적인 이슈

#### 1. Private IP 연결 실패
**증상**: `could not connect to server`
**원인**: VPC Peering 미완료 또는 방화벽 규칙
**해결**: VPC Peering 상태 확인, 방화벽 규칙 검토

#### 2. SSL 인증 오류
**증상**: `SSL connection error`
**원인**: SSL 인증서 검증 실패
**해결**: `sslmode=require` 설정 확인, Cloud SQL SSL 설정 검토

#### 3. postgis 확장 기능 에러
**증상**: `extension "postgis" does not exist`
**원인**: 확장 기능 미설치
**해결**: `CREATE EXTENSION postgis;` 먼저 실행 후 복원

#### 4. PostgreSQL 버전 호환성 에러
**증상**: `function does not exist` (PostgreSQL 17 전용 함수)
**원인**: 버전 다운그레이드로 인한 함수 미지원
**해결**: 백업 SQL에서 해당 함수 제거 또는 수정

#### 5. ExternalSecret 키 불일치 에러
**증상**: `key JWT_REFRESH_SECRET_KEY does not exist in secret`
**원인**: ExternalSecret 템플릿이 GCP Secret Manager의 실제 키와 불일치
**해결**:
- GCP Secret Manager의 실제 키 확인: `gcloud secrets versions access latest --secret="prod-ojeomneo-api-credentials"`
- ExternalSecret 템플릿을 실제 키와 동기화
- Secret Manager에 누락된 키 추가 또는 ExternalSecret에서 존재하지 않는 키 제거

#### 6. Database StatefulSet 계속 생성됨
**증상**: Chart.yaml에서 database dependency 주석 처리했는데도 StatefulSet 생성
**원인**: Chart.lock과 charts/ 디렉토리가 업데이트되지 않음
**해결**:
- `helm dependency update` 실행
- Chart.lock에서 database dependency 제거 확인
- charts/database 디렉토리 삭제
- Git 커밋 및 푸시
- ArgoCD Application 재생성 (필요 시)

---

## 📚 관련 문서

- [GCP Migration Master Plan](../workload/gcp-migration-master-plan.md)
- [Terraform Resources](../../gcp/terraform/TERRAFORM_RESOURCES.md)
- [Cloud SQL Official Documentation](https://cloud.google.com/sql/docs/postgres)
- [PostGIS Documentation](https://postgis.net/documentation/)

---

## 🔄 최종 업데이트 이력

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2025-12-15 | 초안 작성, PostgreSQL 15 사양 확정, 2개 DB 마이그레이션 계획 수립 | Claude |
| 2025-12-16 | Phase 3.1-3.2 완료, ojeomneo ExternalSecret 구성, 문제 해결 사례 추가 | Claude |

---

## 📝 구현 완료 사항 (2025-12-16)

### Cloud SQL 인스턴스
- **Private IP**: 10.38.0.3
- **버전**: PostgreSQL 15
- **인스턴스명**: woohalabs-prod-cloudsql
- **VPC Peering**: 완료
- **IPv4 Public IP**: 활성화 (gcloud sql connect 용)

### ojeomneo 애플리케이션 설정
**ExternalSecret 구성 완료**:
- `ojeomneo-db-credentials` (6개 키)
- `ojeomneo-api-credentials` (18개 키: JWT, Gemini, OpenAI, Firebase, Apple, Cloudflare, Kakao, Email)
- `ojeomneo-admin-credentials` (3개 키: Django Secret, Allowed Hosts, CSRF Origins)

**GCP Secret Manager**:
- `prod-ojeomneo-db-credentials`: Cloud SQL 연결 정보
- `prod-ojeomneo-api-credentials`: API 인증 키 (version 2로 업데이트)
- `prod-ojeomneo-admin-credentials`: Django 설정

**Helm Chart 정리**:
- Database subchart 완전 제거 (Chart.lock 업데이트)
- Redis 비활성화 (프로덕션에서 미사용)
- Chart version: 1.2.0 → 1.3.0

**Pod 상태**:
- ojeomneo-server: 2/2 Running (Cloud SQL 연결)
- ojeomneo-admin: 2/2 Running (Cloud SQL 연결)
- ojeomneo-database: 삭제됨 (구 VM)

### 해결된 문제
1. ServiceMonitor CRD 에러 → Prometheus Operator 미설치로 비활성화
2. ExternalSecret 키 불일치 → GCP Secret Manager와 동기화
3. Database StatefulSet 재생성 → Chart.lock 업데이트 및 subchart 제거
4. Secret 생성 실패 → ExternalSecret 템플릿 수정

### 다음 단계 (Phase 3.3)
- [ ] Cloud SQL에 ojeomneo/reviewmaps 데이터베이스 생성
- [ ] 확장 기능 수동 설치 (pgcrypto, postgis)
- [ ] 백업 데이터 복원
- [ ] 무결성 검증

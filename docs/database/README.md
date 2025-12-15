# Cloud SQL + Secret Manager 통합 문서

**프로젝트**: GCP Cloud SQL PostgreSQL 15 + Secret Manager 통합
**목적**: Secret Manager의 DB credentials로 Cloud SQL 자동 생성 및 관리

---

## 📚 문서 구조

### 1. [QUICKSTART.md](./QUICKSTART.md) - **시작하세요!**
**대상**: 빠르게 시작하고 싶은 사용자
**소요 시간**: 15분
**내용**:
- gcloud로 Secret 생성 (1분)
- 웹 콘솔에서 값 입력 (5분)
- IAM 권한 설정 (1분)
- Terraform으로 Cloud SQL 생성 (5-10분)

### 2. [terraform-secretmanager-integration.md](./terraform-secretmanager-integration.md)
**대상**: Terraform 통합 세부사항을 알고 싶은 사용자
**내용**:
- Secret Manager → Terraform 연동 메커니즘
- Cloud SQL 모듈 구성 상세
- 보안 모범 사례 (State 관리, IAM)
- 트러블슈팅 가이드

### 3. [postgresql-migration-guide.md](./postgresql-migration-guide.md)
**대상**: PostgreSQL 마이그레이션 실행자
**내용**:
- 기존 DB → Cloud SQL 데이터 마이그레이션
- 버전 호환성 (17.5 → 15 다운그레이드)
- PostgreSQL Extensions (pgcrypto, postgis)
- 마이그레이션 테스트 및 롤백

### 4. [../security/secret-manager-setup-manual.md](../security/secret-manager-setup-manual.md)
**대상**: Secret Manager를 웹 콘솔에서 수동으로 설정하는 사용자
**내용**:
- 웹 콘솔 단계별 가이드
- 9개 Secret 상세 JSON 형식
- IAM 권한 설정
- 비용 및 보안 주의사항

---

## 🎯 핵심 아키텍처

### 데이터 흐름

```
1. 사용자가 gcloud로 빈 Secret 생성
   ↓
2. 웹 콘솔에서 실제 비밀번호 입력 (JSON 형식)
   - POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB만 입력
   - POSTGRES_SERVER는 아직 입력 안함 (Cloud SQL 생성 전)
   ↓
3. Terraform이 Secret Manager에서 credentials 읽기
   ↓
4. Cloud SQL 인스턴스 생성
   - PostgreSQL 15
   - Private IP only (VPC Peering)
   - db-g1-small (비용 최적화)
   ↓
5. DB 사용자 생성 (Secret Manager 비밀번호 사용)
   ↓
6. Terraform이 Cloud SQL Private IP를 Secret Manager에 자동 업데이트
   - POSTGRES_SERVER: PLACEHOLDER → 10.128.0.X
   ↓
7. External Secrets Operator가 Kubernetes Secret 동기화
   ↓
8. 애플리케이션 Pod가 Cloud SQL 연결
```

---

## 🔑 핵심 원칙

### 1. Secret은 코드에 넣지 않음
- ❌ Terraform State에 비밀번호 저장 금지
- ❌ `.tf` 파일에 비밀번호 하드코딩 금지
- ✅ Secret Manager에 중앙 관리
- ✅ Terraform은 읽기만 (`data` source 사용)

### 2. POSTGRES_SERVER는 나중에 업데이트
- Cloud SQL 생성 **전**: 사용자명, 비밀번호, DB명만 입력
- Cloud SQL 생성 **후**: Terraform이 Private IP를 자동 업데이트

### 3. 최소 권한 원칙
- Terraform SA: `secretAccessor` (읽기만)
- External Secrets SA: `secretAccessor` (읽기만)
- 사용자: 웹 콘솔에서 `secretAdmin` (생성/수정 가능)

---

## 🏗️ 인프라 구성

### Secret Manager (9개 Secret)

| Secret ID | 용도 | 키 개수 | 비고 |
|-----------|------|---------|------|
| prod-ojeomneo-db-credentials | DB 접속 정보 | 3 | USER, PASSWORD, DB |
| prod-reviewmaps-db-credentials | DB 접속 정보 | 3 | USER, PASSWORD, DB |
| prod-ojeomneo-api-credentials | API 키 | 15+ | OAuth, JWT 등 |
| prod-reviewmaps-api-credentials | API 키 | 20+ | Firebase, Apple 등 |
| prod-ojeomneo-redis-credentials | Redis 접속 | 2 | PASSWORD, HOST |
| prod-ojeomneo-admin-credentials | 관리자 계정 | 2 | USERNAME, PASSWORD |
| prod-reviewmaps-naver-api-credentials | Naver API | 8 | Map, Search, Login |
| prod-monitoring-smtp-credentials | 모니터링 알림 | 6 | SMTP 설정 |
| prod-argocd-dex-credentials | ArgoCD OAuth | 2 | Google OAuth |

### Cloud SQL 구성

| 항목 | 값 |
|------|-----|
| 인스턴스명 | prod-woohalabs-cloudsql |
| 버전 | PostgreSQL 15 |
| 인스턴스 타입 | db-g1-small (1 vCPU, 1.7GB RAM) |
| 스토리지 | 20GB SSD |
| IP 구성 | Private IP only |
| HA | 비활성화 (비용 최적화) |
| 백업 | 비활성화 (수동 백업만) |
| 데이터베이스 | ojeomneo, reviewmaps |
| 사용자 | ojeomneo (owner), reviewmaps (owner) |
| Extensions | pgcrypto, postgis |

---

## 💰 비용 예상

### Secret Manager
- **시크릿 개수**: 9개
- **시크릿당 비용**: $0.06/월
- **API 호출**: 거의 무료 (Terraform apply 시에만)
- **총 비용**: ~$0.54/월

### Cloud SQL
- **인스턴스**: db-g1-small
- **스토리지**: 20GB SSD
- **네트워크**: Private IP (무료)
- **백업**: 비활성화 (수동 백업만)
- **총 비용**: ~$27/월

**총 예상 비용**: ~$27.54/월

---

## ⚙️ Terraform 모듈

### Cloud SQL 모듈
**경로**: `gcp/terraform/modules/cloud-sql/`

**주요 리소스**:
- `google_sql_database_instance.main` - Cloud SQL 인스턴스
- `google_sql_database.ojeomneo` - ojeomneo DB
- `google_sql_database.reviewmaps` - reviewmaps DB
- `google_sql_user.ojeomneo` - ojeomneo 사용자
- `google_sql_user.reviewmaps` - reviewmaps 사용자
- `null_resource.update_*_secret` - Secret Manager 업데이트

**Secret Manager 통합**:
```hcl
# Secret Manager에서 credentials 읽기 (생성 X, 읽기만)
data "google_secret_manager_secret_version" "ojeomneo_db_credentials" {
  secret  = "prod-ojeomneo-db-credentials"
  project = var.project_id
}

# JSON 파싱
locals {
  ojeomneo_creds = jsondecode(data.google_secret_manager_secret_version.ojeomneo_db_credentials.secret_data)
  ojeomneo_user  = local.ojeomneo_creds.POSTGRES_USER
  ojeomneo_pass  = local.ojeomneo_creds.POSTGRES_PASSWORD
}

# Cloud SQL 사용자 생성 (Secret Manager 비밀번호 사용)
resource "google_sql_user" "ojeomneo" {
  name     = local.ojeomneo_user
  password = local.ojeomneo_pass
  instance = google_sql_database_instance.main.name
}
```

---

## 🔐 보안 고려사항

### 1. Secret Manager 접근 제어
- **최소 권한**: 필요한 SA에만 `secretAccessor` 부여
- **감사 로그**: Cloud Audit Logs로 접근 기록 추적
- **버전 관리**: Secret 변경 이력 자동 보관

### 2. Terraform State 보안
- ✅ `data` source 사용 (비밀번호 State에 저장 안됨)
- ✅ State는 GCS backend에 암호화 저장
- ❌ 절대로 `resource`로 Secret 생성하지 않음

### 3. Cloud SQL 보안
- ✅ Private IP only (공인 IP 비활성화)
- ✅ SSL/TLS 필수
- ✅ VPC Peering으로 네트워크 격리
- ✅ IAM 기반 접근 제어

### 4. backup_secrets/ 정리
- Secret Manager 마이그레이션 완료 후 **즉시 삭제**
- Git 히스토리에서 완전 제거 (BFG Repo-Cleaner)
- `.gitignore`에 `backup_secrets/` 추가 확인

---

## 🧪 테스트 및 검증

### 1. Secret Manager 확인
```bash
# Secret 목록
gcloud secrets list --project=infra-480802 | grep prod-

# Secret 내용 확인 (JSON 검증)
gcloud secrets versions access latest \
  --secret=prod-ojeomneo-db-credentials \
  --project=infra-480802 | jq .
```

### 2. Cloud SQL 연결 테스트
```bash
# Cloud SQL Proxy
cloud_sql_proxy -instances=infra-480802:asia-northeast3:prod-woohalabs-cloudsql=tcp:5432

# psql 연결
psql -h 127.0.0.1 -U ojeomneo -d ojeomneo
```

### 3. Kubernetes Secret 동기화 확인
```bash
# ExternalSecret 상태
kubectl get externalsecrets -A

# Kubernetes Secret 확인
kubectl get secret ojeomneo-db-credentials -n ojeomneo -o yaml
```

---

## 📖 관련 문서

### GCP 공식 문서
- [Secret Manager 문서](https://cloud.google.com/secret-manager/docs)
- [Cloud SQL for PostgreSQL](https://cloud.google.com/sql/docs/postgres)
- [VPC Peering](https://cloud.google.com/vpc/docs/vpc-peering)

### Terraform Provider
- [Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Secret Manager Data Source](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version)
- [Cloud SQL Resources](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance)

### External Secrets Operator
- [External Secrets 공식 문서](https://external-secrets.io/)
- [GCP Secret Manager Provider](https://external-secrets.io/latest/provider/google-secrets-manager/)

---

## 🚀 시작하기

**바로 시작하려면**: [QUICKSTART.md](./QUICKSTART.md)를 참고하세요!

1. `bash scripts/create-secrets.sh` - Secret 생성
2. 웹 콘솔에서 값 입력 (USER, PASSWORD, DB만)
3. `bash scripts/setup-secret-iam.sh` - IAM 권한
4. `terraform apply` - Cloud SQL 생성

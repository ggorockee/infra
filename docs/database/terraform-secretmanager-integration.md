# Terraform과 Secret Manager DB Credentials 통합 가이드

**최종 업데이트**: 2025-12-15
**대상**: Cloud SQL 모듈과 Secret Manager 연동
**목적**: DB credentials를 Secret Manager에서 읽어 Cloud SQL 인스턴스 생성

---

## 📋 개요

### 목표
Secret Manager에 저장된 DB credentials (사용자명, 비밀번호)를 Terraform이 읽어서 Cloud SQL 인스턴스 생성 시 사용

### 통합 흐름
```
1. Secret Manager에 DB credentials 저장 (JSON 형식)
   ↓
2. Terraform이 Secret Manager에서 credentials 읽기
   ↓
3. Cloud SQL 인스턴스 생성
   ↓
4. Cloud SQL 사용자 생성 (Secret Manager 비밀번호 사용)
   ↓
5. Secret Manager에 연결 정보 업데이트 (Private IP 추가)
   ↓
6. External Secrets Operator가 Kubernetes Secret 동기화
```

---

## 🔑 Secret Manager 준비

### 1. DB Credentials Secret 생성

**Ojeomneo DB Credentials**:
```bash
# prod-ojeomneo-db-credentials 시크릿 생성
gcloud secrets create prod-ojeomneo-db-credentials \
  --replication-policy=user-managed \
  --locations=asia-northeast3 \
  --project=infra-480802
```

**초기 JSON 데이터**:
```json
{
  "POSTGRES_USER": "ojeomneo",
  "POSTGRES_PASSWORD": "rlavhWkdWkdaos!1",
  "POSTGRES_SERVER": "PLACEHOLDER",
  "POSTGRES_PORT": "5432",
  "POSTGRES_DB": "ojeomneo"
}
```

**시크릿 버전 추가**:
```bash
cat <<EOF | gcloud secrets versions add prod-ojeomneo-db-credentials \
  --data-file=- \
  --project=infra-480802
{
  "POSTGRES_USER": "ojeomneo",
  "POSTGRES_PASSWORD": "rlavhWkdWkdaos!1",
  "POSTGRES_SERVER": "PLACEHOLDER",
  "POSTGRES_PORT": "5432",
  "POSTGRES_DB": "ojeomneo"
}
EOF
```

**ReviewMaps DB Credentials**:
```bash
# prod-reviewmaps-db-credentials 시크릿 생성
gcloud secrets create prod-reviewmaps-db-credentials \
  --replication-policy=user-managed \
  --locations=asia-northeast3 \
  --project=infra-480802

# 초기 JSON 데이터 추가
cat <<EOF | gcloud secrets versions add prod-reviewmaps-db-credentials \
  --data-file=- \
  --project=infra-480802
{
  "POSTGRES_USER": "reviewmaps",
  "POSTGRES_PASSWORD": "Reviewmaps1120$",
  "POSTGRES_SERVER": "PLACEHOLDER",
  "POSTGRES_PORT": "5432",
  "POSTGRES_DB": "reviewmaps"
}
EOF
```

### 2. Terraform Service Account 권한 부여

```bash
# Terraform이 Secret Manager를 읽을 수 있도록 권한 부여
gcloud projects add-iam-policy-binding infra-480802 \
  --member="serviceAccount:terraform@infra-480802.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## 🏗️ Terraform 구성

### 1. Secret Manager에서 Credentials 읽기

**[gcp/terraform/modules/cloud-sql/main.tf](../../gcp/terraform/modules/cloud-sql/main.tf)**:

```hcl
# Secret Manager에서 DB Credentials 읽기
data "google_secret_manager_secret_version" "ojeomneo_db_credentials" {
  secret  = "prod-ojeomneo-db-credentials"
  project = var.project_id
}

data "google_secret_manager_secret_version" "reviewmaps_db_credentials" {
  secret  = "prod-reviewmaps-db-credentials"
  project = var.project_id
}

# JSON 파싱
locals {
  ojeomneo_creds = jsondecode(data.google_secret_manager_secret_version.ojeomneo_db_credentials.secret_data)
  ojeomneo_user  = local.ojeomneo_creds.POSTGRES_USER
  ojeomneo_pass  = local.ojeomneo_creds.POSTGRES_PASSWORD
  ojeomneo_db    = local.ojeomneo_creds.POSTGRES_DB

  reviewmaps_creds = jsondecode(data.google_secret_manager_secret_version.reviewmaps_db_credentials.secret_data)
  reviewmaps_user  = local.reviewmaps_creds.POSTGRES_USER
  reviewmaps_pass  = local.reviewmaps_creds.POSTGRES_PASSWORD
  reviewmaps_db    = local.reviewmaps_creds.POSTGRES_DB
}
```

### 2. Cloud SQL 사용자 생성 (Secret Manager 비밀번호 사용)

```hcl
# Ojeomneo User
resource "google_sql_user" "ojeomneo" {
  name     = local.ojeomneo_user      # Secret Manager에서 가져온 사용자명
  instance = google_sql_database_instance.main.name
  password = local.ojeomneo_pass      # Secret Manager에서 가져온 비밀번호
  project  = var.project_id

  depends_on = [google_sql_database.ojeomneo]
}

# ReviewMaps User
resource "google_sql_user" "reviewmaps" {
  name     = local.reviewmaps_user    # Secret Manager에서 가져온 사용자명
  instance = google_sql_database_instance.main.name
  password = local.reviewmaps_pass    # Secret Manager에서 가져온 비밀번호
  project  = var.project_id

  depends_on = [google_sql_database.reviewmaps]
}
```

### 3. Cloud SQL 생성 후 연결 정보 업데이트

**Cloud SQL Private IP를 Secret Manager에 자동 업데이트**:

```hcl
# Ojeomneo DB 연결 정보 업데이트
resource "null_resource" "update_ojeomneo_secret" {
  provisioner "local-exec" {
    command = <<-EOT
      # 기존 Secret에서 모든 키 가져오기
      EXISTING_SECRET=$(gcloud secrets versions access latest \
        --secret=prod-ojeomneo-db-credentials \
        --project=${var.project_id})

      # POSTGRES_SERVER만 Cloud SQL Private IP로 업데이트
      UPDATED_SECRET=$(echo "$EXISTING_SECRET" | jq \
        --arg server "${google_sql_database_instance.main.private_ip_address}" \
        '.POSTGRES_SERVER = $server')

      # 새 버전 추가
      echo -n "$UPDATED_SECRET" | gcloud secrets versions add prod-ojeomneo-db-credentials \
        --data-file=- \
        --project=${var.project_id}
    EOT
  }

  depends_on = [google_sql_database_instance.main]
}
```

---

## 🔄 통합 워크플로우

### 1단계: Secret Manager에 초기 Credentials 저장
- `POSTGRES_SERVER`: PLACEHOLDER (Cloud SQL 생성 전이므로)
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`: 실제 값

### 2단계: Terraform Apply
```bash
cd gcp/terraform/environments/prod
terraform init
terraform plan
terraform apply
```

### 3단계: Terraform이 수행하는 작업
1. Secret Manager에서 `prod-ojeomneo-db-credentials`, `prod-reviewmaps-db-credentials` 읽기
2. JSON 파싱하여 사용자명, 비밀번호 추출
3. Cloud SQL 인스턴스 생성 (PostgreSQL 15)
4. Cloud SQL 사용자 생성 (Secret Manager 비밀번호 사용)
5. Cloud SQL Private IP를 Secret Manager에 자동 업데이트

### 4단계: Secret Manager 최종 상태
```json
{
  "POSTGRES_USER": "ojeomneo",
  "POSTGRES_PASSWORD": "rlavhWkdWkdaos!1",
  "POSTGRES_SERVER": "10.128.0.3",  // Cloud SQL Private IP (자동 업데이트)
  "POSTGRES_PORT": "5432",
  "POSTGRES_DB": "ojeomneo"
}
```

### 5단계: External Secrets Operator 동기화
- ExternalSecret이 Secret Manager에서 최신 버전 읽기
- Kubernetes Secret 자동 생성/업데이트
- 애플리케이션 Pod에서 Cloud SQL 연결 가능

---

## 🔐 보안 모범 사례

### 1. Terraform State 보안

**중요**: Terraform State에 비밀번호가 저장되지 않도록 주의

**방법 1: Data Source 사용** (현재 구현)
- `data.google_secret_manager_secret_version` 사용
- State에는 Secret ID만 저장, 실제 비밀번호는 저장되지 않음

**방법 2: lifecycle.ignore_changes** (추가 보호)
```hcl
resource "google_sql_user" "ojeomneo" {
  name     = local.ojeomneo_user
  instance = google_sql_database_instance.main.name
  password = local.ojeomneo_pass

  lifecycle {
    ignore_changes = [password]
  }
}
```

### 2. Secret Manager Access Control

**최소 권한 원칙**:
```bash
# Terraform SA: secretAccessor만 부여 (생성/삭제 권한 없음)
gcloud secrets add-iam-policy-binding prod-ojeomneo-db-credentials \
  --member="serviceAccount:terraform@infra-480802.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=infra-480802
```

### 3. Secret 버전 관리

**버전 히스토리 추적**:
```bash
# Secret 버전 목록 확인
gcloud secrets versions list prod-ojeomneo-db-credentials \
  --project=infra-480802

# 특정 버전 확인
gcloud secrets versions access 2 \
  --secret=prod-ojeomneo-db-credentials \
  --project=infra-480802
```

**이전 버전으로 롤백**:
```bash
# External Secrets Operator가 자동으로 최신 버전 사용
# 롤백 필요 시: 이전 버전을 새 버전으로 추가
gcloud secrets versions access 1 \
  --secret=prod-ojeomneo-db-credentials \
  --project=infra-480802 | \
gcloud secrets versions add prod-ojeomneo-db-credentials \
  --data-file=- \
  --project=infra-480802
```

---

## ⚠️ 주의사항

### 1. 순환 의존성 방지

**문제**: Secret Manager에 Cloud SQL Private IP를 업데이트하려면 Cloud SQL이 먼저 생성되어야 함

**해결책**: `null_resource`와 `depends_on` 사용
- Cloud SQL 인스턴스 생성 → Private IP 확인 → Secret Manager 업데이트

### 2. 비밀번호 변경 시나리오

**시나리오 1**: Secret Manager에서 비밀번호만 변경
```bash
# Secret Manager 비밀번호 변경
gcloud secrets versions add prod-ojeomneo-db-credentials \
  --data-file=updated_credentials.json \
  --project=infra-480802

# Cloud SQL 사용자 비밀번호 수동 변경 필요
gcloud sql users set-password ojeomneo \
  --instance=prod-woohalabs-cloudsql \
  --password=NEW_PASSWORD \
  --project=infra-480802
```

**시나리오 2**: Terraform으로 비밀번호 변경
- Secret Manager 업데이트 → `terraform apply` → Cloud SQL 사용자 비밀번호 자동 변경

### 3. 초기 배포 시 순서

**올바른 순서**:
1. Secret Manager에 초기 credentials 저장
2. `terraform plan` 실행 (검증)
3. `terraform apply` 실행 (Cloud SQL 생성)
4. Secret Manager 자동 업데이트 (Private IP)
5. External Secrets Operator 동기화 확인

---

## 📊 비용 영향

### Secret Manager 비용
- **시크릿 개수**: 2개 (prod-ojeomneo-db-credentials, prod-reviewmaps-db-credentials)
- **버전당 비용**: $0.06/월
- **API 호출**: Terraform apply 시에만 발생 (거의 무료)

**총 비용**: ~$0.12/월 (2개 시크릿)

### Cloud SQL 비용
- **인스턴스**: db-g1-small (1 vCPU, 1.7GB RAM)
- **스토리지**: 20GB SSD
- **백업**: 비활성화 (수동 백업만 사용)

**총 비용**: ~$27/월

---

## 🧪 테스트 및 검증

### 1. Secret Manager 읽기 테스트

```bash
# Terraform이 Secret을 읽을 수 있는지 확인
terraform console
> jsondecode(data.google_secret_manager_secret_version.ojeomneo_db_credentials.secret_data)
```

### 2. Cloud SQL 연결 테스트

```bash
# Cloud SQL Private IP 확인
terraform output private_ip_address

# Cloud Proxy를 통한 연결 테스트
cloud_sql_proxy -instances=infra-480802:asia-northeast3:prod-woohalabs-cloudsql=tcp:5432

# psql 연결
psql -h 127.0.0.1 -U ojeomneo -d ojeomneo
```

### 3. Kubernetes Secret 동기화 확인

```bash
# ExternalSecret 상태 확인
kubectl get externalsecrets -n ojeomneo

# Kubernetes Secret 확인
kubectl get secret ojeomneo-db-credentials -n ojeomneo -o yaml

# Secret 내용 디코딩
kubectl get secret ojeomneo-db-credentials -n ojeomneo \
  -o jsonpath='{.data.POSTGRES_SERVER}' | base64 -d
```

---

## 🔧 트러블슈팅

### 문제 1: Terraform이 Secret을 읽지 못함

**증상**:
```
Error: Error reading secret version: googleapi: Error 403: Permission 'secretmanager.versions.access' denied
```

**해결**:
```bash
# Terraform SA에 권한 부여
gcloud projects add-iam-policy-binding infra-480802 \
  --member="serviceAccount:terraform@infra-480802.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 문제 2: Cloud SQL 사용자 생성 실패

**증상**:
```
Error: Error creating user: googleapi: Error 409: User already exists
```

**해결**:
```bash
# 기존 사용자 삭제 (주의: 프로덕션에서는 신중하게)
gcloud sql users delete ojeomneo \
  --instance=prod-woohalabs-cloudsql \
  --project=infra-480802

# Terraform 재실행
terraform apply
```

### 문제 3: Secret Manager 업데이트 실패

**증상**:
```
Error: local-exec provisioner error: jq: command not found
```

**해결**:
```bash
# jq 설치 (GitHub Actions runner에서)
sudo apt-get update && sudo apt-get install -y jq

# 로컬 환경
brew install jq  # macOS
```

---

## 📚 참고 자료

- [Google Secret Manager 문서](https://cloud.google.com/secret-manager/docs)
- [Terraform Google Provider - Secret Manager](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version)
- [Cloud SQL Best Practices](https://cloud.google.com/sql/docs/postgres/best-practices)
- [External Secrets Operator](https://external-secrets.io/)

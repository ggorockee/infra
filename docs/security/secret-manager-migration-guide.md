# Google Secret Manager 마이그레이션 가이드 (JSON 통합 방식)

**최종 업데이트**: 2025-12-15
**대상 환경**: GCP Cloud Secret Manager (infra-480802)
**마이그레이션 대상**: backup_secrets/ 디렉토리의 9개 시크릿 파일
**비용 최적화**: JSON 통합 방식으로 **85% 비용 절감** ($14.40 → $2.16/월)

---

## 🚨 긴급성

**현재 상황**:
- `backup_secrets/` 디렉토리에 9개의 민감한 시크릿 파일 존재
- DB 비밀번호, API 키, Private Key 등 매우 중요한 정보 포함
- **Git에 커밋되면 보안 사고 발생** (복구 불가능)

**해결책**: Google Secret Manager로 즉시 마이그레이션 (JSON 통합 방식)

---

## 📋 마이그레이션 개요

### 목표
1. backup_secrets/ 시크릿을 Google Secret Manager로 안전하게 이전
2. **JSON 통합 방식**으로 비용 85% 절감 (60개 → 9개 시크릿)
3. External Secrets Operator를 통해 Kubernetes Secret 자동 동기화
4. Git 히스토리에서 시크릿 완전 제거
5. PostgreSQL 데이터베이스 백업 및 복원 준비

### 데이터베이스 백업 정보

**위치**: `backupsql/`

| 백업 파일 | 데이터베이스 | 용도 |
|----------|------------|------|
| backupsql/ojeomneo_backup.sql | ojeomneo | Ojeomneo 애플리케이션 DB |
| backupsql/reviewmaps_backup.sql | reviewmaps | ReviewMaps 애플리케이션 DB |

**PostgreSQL 버전**:
- Ojeomneo: PostgreSQL 15
- ReviewMaps: PostgreSQL 17.5 → 15로 다운그레이드 필요

**필수 Extensions**:
- ReviewMaps: `pgcrypto`, `postgis` (공간 데이터 지원)

### Istio 서비스 메시 구조

**위치**: `charts/helm/prod/`

| Helm 차트 | 용도 | 네임스페이스 |
|----------|------|-------------|
| istio-base | Istio CRD 정의 | istio-system |
| istiod | Istio Daemon (Control Plane) | istio-system |
| istio-ingressgateway | Istio Ingress Gateway | istio-system |
| istio-gateway-config | Gateway 및 VirtualService 설정 | default |

**Istio 아키텍처**:
```
인터넷
  ↓
Istio Ingress Gateway (istio-system)
  ↓
Istio Gateway + VirtualService (istio-gateway-config)
  ↓
애플리케이션 Pod (ojeomneo, reviewmaps)
```

**주요 기능**:
- 트래픽 관리 (라우팅, 로드 밸런싱)
- 보안 (mTLS, 인증/인가)
- 관찰성 (메트릭, 로그, 추적)
- Rate Limiting (비용 최소화)

### 기대 효과
- ✅ Git 저장소에서 시크릿 완전 분리 (보안 강화)
- ✅ 시크릿 중앙 관리 (Google Secret Manager)
- ✅ 자동 동기화 (External Secrets Operator)
- ✅ **월 비용 $2.16** (개별 키 방식 대비 85% 절감)
- ✅ 관리 단순화 (9개 JSON 시크릿만 관리)

### 예상 소요 기간
- **총 6일** (하루 2-4시간 작업 기준)

---

## 📊 시크릿 인벤토리

### 마이그레이션 대상 (9개 JSON 시크릿)

| Secret Manager ID | 소스 파일 | 네임스페이스 | 키 개수 | 민감도 |
|------------------|----------|-------------|--------|--------|
| prod-ojeomneo-db-credentials | ojeomneo-db-credentials.yaml | ojeomneo | 5 | 🔴 Critical |
| prod-ojeomneo-api-credentials | ojeomneo-api-credentials.yaml | ojeomneo | 15+ | 🔴 Critical |
| prod-ojeomneo-redis-credentials | ojeomneo-redis-credentials.yaml | ojeomneo | 2 | 🟡 High |
| prod-ojeomneo-admin-credentials | ojeomneo-admin-credentials.yaml | ojeomneo | 2 | 🟡 High |
| prod-reviewmaps-db-credentials | reviewmaps-db-credentials.yaml | reviewmaps | 8 | 🔴 Critical |
| prod-reviewmaps-api-credentials | reviewmaps-api-credentials.yaml | reviewmaps | 20+ | 🔴 Critical |
| prod-reviewmaps-naver-api-credentials | naver-api-creds.yaml | reviewmaps | 8 | 🟢 Medium |
| prod-monitoring-smtp-credentials | alertmanager-smtp-credentials.yaml | monitoring | 6 | 🟡 High |
| prod-argocd-dex-credentials | argocd-dex-secret.yaml | argocd | 2 | 🟡 High |

---

## 🏗️ Secret Manager 구조 설계 (JSON 통합)

### 네이밍 컨벤션

**형식**: `{environment}-{namespace}-{category}-credentials`

**예시**:
```
prod-ojeomneo-db-credentials
prod-reviewmaps-api-credentials
prod-monitoring-smtp-credentials
```

### JSON 시크릿 구조 예시

#### 1. prod-ojeomneo-db-credentials
```json
{
  "POSTGRES_USER": "YOUR_DB_USER",
  "POSTGRES_PASSWORD": "YOUR_SECURE_PASSWORD",
  "POSTGRES_SERVER": "YOUR_DB_SERVER.svc.cluster.local",
  "POSTGRES_PORT": "5432",
  "POSTGRES_DB": "YOUR_DATABASE_NAME"
}
```

#### 2. prod-reviewmaps-api-credentials
```json
{
  "API_SECRET_KEY": "YOUR_API_SECRET_KEY_64_CHARS_HEX",
  "JWT_SECRET_KEY": "YOUR_JWT_SECRET_KEY",
  "KAKAO_REST_API_KEY": "YOUR_KAKAO_API_KEY",
  "GOOGLE_CLIENT_ID_IOS": "YOUR_GOOGLE_CLIENT_ID",
  "FIREBASE_CREDENTIALS": "{\"type\":\"service_account\",\"project_id\":\"YOUR_PROJECT\"}",
  "APPLE_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\nYOUR_APPLE_PRIVATE_KEY\n-----END PRIVATE KEY-----",
  "EMAIL_HOST": "smtp.gmail.com",
  "EMAIL_HOST_PASSWORD": "YOUR_EMAIL_APP_PASSWORD"
}
```

### 레이블 전략

```
environment = "prod"
namespace   = "ojeomneo" | "reviewmaps" | "monitoring" | "argocd"
app         = "ojeomneo" | "reviewmaps" | "alertmanager" | "argocd"
managed_by  = "terraform"
secret_type = "database" | "api" | "infrastructure" | "oauth"
```

---

## 🔧 Secret Manager 생성 방법 (gcloud CLI)

### ⚠️ Terraform으로 Secret 생성하지 않는 이유
- ❌ Terraform State에 비밀번호 평문 저장
- ❌ `.tf` 파일에 비밀번호 하드코딩 필요
- ❌ CI/CD 로그에 노출 위험
- ❌ Git 커밋 시 보안 사고 가능성

### ✅ gcloud CLI로 빈 Secret 생성 후 웹 콘솔에서 값 입력

#### 1단계: gcloud로 빈 Secret 생성

**스크립트 실행**:
```bash
bash scripts/create-secrets.sh
```

**스크립트 내용**:
- 9개 Secret을 빈 상태로 생성
- 레이블 자동 설정 (env, app, category)
- 리전: asia-northeast3
- 이미 존재하면 스킵

#### 2단계: 웹 콘솔에서 실제 값 추가

**방법**:
1. GCP 콘솔 → Secret Manager 이동
   https://console.cloud.google.com/security/secret-manager?project=infra-480802

2. 각 Secret 클릭 → "NEW VERSION" 버튼

3. backup_secrets/ 디렉토리의 YAML 파일을 JSON으로 변환하여 입력

**예시**:
```json
{
  "POSTGRES_USER": "YOUR_DB_USER",
  "POSTGRES_PASSWORD": "YOUR_SECURE_PASSWORD",
  "POSTGRES_SERVER": "PLACEHOLDER",
  "POSTGRES_PORT": "5432",
  "POSTGRES_DB": "YOUR_DATABASE_NAME"
}
```

#### 3단계: IAM 권한 설정

**스크립트 실행**:
```bash
bash scripts/setup-secret-iam.sh
```

**권한 부여 대상**:
- Terraform SA: Secret 읽기 (Cloud SQL 생성 시 사용)
- External Secrets SA: Secret 읽기 (Kubernetes Secret 동기화)

---

## 🏗️ Terraform 통합 (Secret은 읽기만)

### ⚠️ Terraform 실행 규칙

**🔴 CRITICAL**: Terraform은 **반드시 Git CI/CD를 통해서만** 실행합니다.

**로컬 실행 금지 사유**:
- ❌ GCP 인증 정보는 GitHub Actions Secrets에만 존재
- ❌ 로컬 환경에는 GCP 서비스 계정 키가 없음
- ❌ 보안상 로컬에 프로덕션 인증 정보 저장 금지

**올바른 실행 방법**:
1. Feature 브랜치에서 Terraform 코드 작성
2. Git 푸시 후 PR 생성
3. GitHub Actions에서 `terraform plan` 자동 실행
4. PR 리뷰 후 Merge → `terraform apply` 자동 실행

**로컬에서 가능한 작업**:
- ✅ `terraform init`: Provider 다운로드
- ✅ `terraform validate`: 문법 검증
- ✅ `terraform fmt`: 코드 포맷팅
- ❌ `terraform plan`: GitHub Actions에서만
- ❌ `terraform apply`: GitHub Actions에서만

### Cloud SQL 모듈에서 Secret 읽기

Terraform이 **이미 존재하는 Secret을 읽어서** Cloud SQL 사용자 생성:

```hcl
# Secret Manager에서 DB Credentials 읽기 (생성 X, 읽기만)
data "google_secret_manager_secret_version" "ojeomneo_db_credentials" {
  secret      = google_secret_manager_secret.ojeomneo_db_credentials.id
  secret_data = jsonencode({
    POSTGRES_USER     = "PLACEHOLDER"
    POSTGRES_PASSWORD = "PLACEHOLDER"
    POSTGRES_SERVER   = "PLACEHOLDER"
    POSTGRES_PORT     = "PLACEHOLDER"
    POSTGRES_DB       = "PLACEHOLDER"
  })

  lifecycle {
    ignore_changes = [secret_data]
  }
}

# prod-reviewmaps-api-credentials (JSON)
resource "google_secret_manager_secret" "reviewmaps_api_credentials" {
  secret_id = "prod-reviewmaps-api-credentials"
  project   = var.project_id

  labels = {
    environment = "prod"
    namespace   = "reviewmaps"
    app         = "reviewmaps"
    managed_by  = "terraform"
    secret_type = "api"
  }

  replication {
    user_managed {
      replicas {
        location = "asia-northeast3"
      }
    }
  }
}

# ... 나머지 7개 시크릿도 동일한 패턴
```

### external-secrets.tf 예시 (JSON 통합 - dataFrom 방식)

```hcl
# ojeomneo-db-credentials ExternalSecret
resource "kubernetes_manifest" "ojeomneo_db_credentials" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "ojeomneo-db-credentials"
      namespace = "ojeomneo"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "gcpsm-secret-store"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "ojeomneo-db-credentials"
        creationPolicy = "Owner"
      }
      # dataFrom으로 JSON 전체를 Kubernetes Secret으로 변환
      dataFrom = [
        {
          extract = {
            key = "prod-ojeomneo-db-credentials"
          }
        }
      ]
    }
  }
}

# reviewmaps-api-credentials ExternalSecret
resource "kubernetes_manifest" "reviewmaps_api_credentials" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "reviewmaps-api-credentials"
      namespace = "reviewmaps"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "gcpsm-secret-store"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "reviewmaps-api-credentials"
        creationPolicy = "Owner"
      }
      dataFrom = [
        {
          extract = {
            key = "prod-reviewmaps-api-credentials"
          }
        }
      ]
    }
  }
}

# ... 나머지 7개 ExternalSecret도 동일한 패턴
```

**중요**: `dataFrom.extract` 방식은 Secret Manager의 JSON을 자동으로 파싱하여 Kubernetes Secret의 여러 키로 분리합니다.

### 시크릿 주입 스크립트 (JSON 변환)

**scripts/inject-secrets.sh**:

```bash
#!/bin/bash
# Secret Manager에 JSON 형식으로 시크릿 주입
set -e

PROJECT_ID="infra-480802"
SECRETS_DIR="${1:-backup_secrets}"
DRY_RUN=false

# --dry-run 플래그 확인
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  SECRETS_DIR="${2:-backup_secrets}"
fi

echo "🔐 Secret Manager 마이그레이션 시작 (JSON 통합 방식)..."
echo "📂 소스 디렉토리: $SECRETS_DIR"
echo "🌐 GCP 프로젝트: $PROJECT_ID"
echo ""

# yq 설치 확인
if ! command -v yq &> /dev/null; then
    echo "❌ yq가 설치되어 있지 않습니다."
    echo "   brew install yq (macOS)"
    exit 1
fi

# JSON 주입 함수
inject_json_secret() {
    local secret_id=$1
    local json_data=$2

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] $secret_id 주입 예정"
        echo "  JSON: $(echo "$json_data" | jq -c .)"
        return
    fi

    echo "  ↳ $secret_id 주입 중..."
    echo -n "$json_data" | gcloud secrets versions add "$secret_id" \
        --project="$PROJECT_ID" \
        --data-file=- 2>&1 | grep -v "Created version"
}

# 1. ojeomneo-db-credentials
echo "📦 prod-ojeomneo-db-credentials 마이그레이션 중..."
FILE="$SECRETS_DIR/ojeomneo-db-credentials.yaml"
if [ -f "$FILE" ]; then
    JSON=$(jq -n \
        --arg user "$(yq eval '.stringData.POSTGRES_USER' $FILE)" \
        --arg password "$(yq eval '.stringData.POSTGRES_PASSWORD' $FILE)" \
        --arg server "$(yq eval '.stringData.POSTGRES_SERVER' $FILE)" \
        --arg port "$(yq eval '.stringData.POSTGRES_PORT' $FILE)" \
        --arg db "$(yq eval '.stringData.POSTGRES_DB' $FILE)" \
        '{
          POSTGRES_USER: $user,
          POSTGRES_PASSWORD: $password,
          POSTGRES_SERVER: $server,
          POSTGRES_PORT: $port,
          POSTGRES_DB: $db
        }')
    inject_json_secret "prod-ojeomneo-db-credentials" "$JSON"
    echo "✅ prod-ojeomneo-db-credentials 완료"
fi

# 2. reviewmaps-api-credentials (복잡한 JSON)
echo "📦 prod-reviewmaps-api-credentials 마이그레이션 중..."
FILE="$SECRETS_DIR/reviewmaps-api-credentials.yaml"
if [ -f "$FILE" ]; then
    JSON=$(jq -n \
        --arg api_secret "$(yq eval '.stringData.API_SECRET_KEY' $FILE)" \
        --arg jwt_secret "$(yq eval '.stringData.JWT_SECRET_KEY' $FILE)" \
        --arg kakao_key "$(yq eval '.stringData.KAKAO_REST_API_KEY' $FILE)" \
        --arg google_ios "$(yq eval '.stringData.GOOGLE_CLIENT_ID_IOS' $FILE)" \
        --arg google_android "$(yq eval '.stringData.GOOGLE_CLIENT_ID_ANDROID' $FILE)" \
        --arg firebase_creds "$(yq eval '.stringData.FIREBASE_CREDENTIALS' $FILE)" \
        --arg apple_key "$(yq eval '.stringData.APPLE_PRIVATE_KEY' $FILE)" \
        --arg email_host "$(yq eval '.stringData.EMAIL_HOST' $FILE)" \
        --arg email_password "$(yq eval '.stringData.EMAIL_HOST_PASSWORD' $FILE)" \
        '{
          API_SECRET_KEY: $api_secret,
          JWT_SECRET_KEY: $jwt_secret,
          KAKAO_REST_API_KEY: $kakao_key,
          GOOGLE_CLIENT_ID_IOS: $google_ios,
          GOOGLE_CLIENT_ID_ANDROID: $google_android,
          FIREBASE_CREDENTIALS: $firebase_creds,
          APPLE_PRIVATE_KEY: $apple_key,
          EMAIL_HOST: $email_host,
          EMAIL_HOST_PASSWORD: $email_password
        }')
    inject_json_secret "prod-reviewmaps-api-credentials" "$JSON"
    echo "✅ prod-reviewmaps-api-credentials 완료"
fi

# ... 나머지 7개 시크릿도 동일한 패턴

echo ""
echo "✅ 모든 시크릿 마이그레이션 완료!"
echo "🔍 검증: gcloud secrets list --project=$PROJECT_ID"
```

---

## 🚀 마이그레이션 단계별 절차

### Phase 1: 준비 및 Terraform 모듈 개발 (1일차)

#### 1.1 Terraform 모듈 작성
```bash
mkdir -p gcp/terraform/modules/secret-manager
```

**작업 내용**:
- [ ] `main.tf`: **9개** Secret Manager 리소스 (JSON)
- [ ] `external-secrets.tf`: **9개** ExternalSecret 리소스 (`dataFrom.extract`)
- [ ] `variables.tf`, `outputs.tf`, `README.md`

#### 1.2 시크릿 주입 스크립트
```bash
touch scripts/inject-secrets.sh
chmod +x scripts/inject-secrets.sh
```

**기능**:
- YAML → JSON 변환
- Secret Manager 주입
- Dry-run 모드

#### 1.3 .gitignore 업데이트
```bash
cat >> .gitignore << 'EOF'
backup_secrets/
backupsql/
*.secret
*.key
*.pem
*-credentials.yaml
*-secret.yaml
EOF
```

#### 1.4 로컬 테스트
```bash
cd gcp/terraform/environments/prod
terraform init
terraform plan
```

**예상 출력**:
```
Plan: 18 to add, 0 to change, 0 to destroy.
(9개 Secret Manager + 9개 ExternalSecret)
```

**예상 소요 시간**: 3-4시간 (개별 키 방식보다 30% 단축)

---

### Phase 2: Terraform Apply 및 시크릿 주입 (2일차)

#### 2.1 Feature 브랜치 생성
```bash
git checkout -b feature/secret-manager-json-migration
git add gcp/terraform/modules/secret-manager/
git add scripts/inject-secrets.sh
git add .gitignore
git commit -m "feat: Add Secret Manager with JSON integration

- 9개 JSON Secret Manager 리소스
- 85% 비용 절감 ($14.40 → $2.16/월)
- dataFrom.extract 방식 ExternalSecret"

git push origin feature/secret-manager-json-migration
```

#### 2.2 GitHub Actions Apply
1. PR 생성
2. Terraform Plan 확인 (18개 리소스)
3. PR Merge
4. Terraform Apply 자동 실행
5. Secret Manager에 9개 빈 JSON 시크릿 생성 확인

#### 2.3 JSON 시크릿 주입
```bash
# Dry-run 테스트
./scripts/inject-secrets.sh --dry-run backup_secrets/

# 실제 주입
./scripts/inject-secrets.sh backup_secrets/
```

**검증**:
```bash
# JSON 시크릿 확인
gcloud secrets versions access latest --secret="prod-ojeomneo-db-credentials" --project=infra-480802

# 출력 예시:
# {"POSTGRES_USER":"YOUR_DB_USER","POSTGRES_PASSWORD":"YOUR_SECURE_PASSWORD",...}
```

---

### Phase 3: ExternalSecret 배포 및 검증 (3일차)

#### 3.1 ExternalSecret 확인
```bash
kubectl get externalsecrets -A
```

**예상 출력**: 9개 모두 `SecretSynced`

#### 3.2 Kubernetes Secret 검증
```bash
# JSON이 자동으로 여러 키로 분리됨
kubectl get secret ojeomneo-db-credentials -n ojeomneo -o jsonpath='{.data}' | jq 'keys'

# 예상 출력:
# ["POSTGRES_DB", "POSTGRES_PASSWORD", "POSTGRES_PORT", "POSTGRES_SERVER", "POSTGRES_USER"]
```

**중요**: `dataFrom.extract`가 JSON을 자동 파싱하여 Kubernetes Secret에 여러 키로 분리합니다!

---

### Phase 4-6: 애플리케이션 통합, 백업 정리, 문서화

(기존 가이드와 동일, 생략)

---

## 💰 비용 비교 (JSON 통합 vs 개별 키)

| 항목 | 개별 키 방식 | JSON 통합 방식 | 절감액 |
|-----|-------------|---------------|--------|
| 시크릿 수 | 60개 | 9개 | -51개 |
| 시크릿 저장 비용 | $3.60/월 | $0.54/월 | **-$3.06** |
| 버전 저장 (3버전) | $10.80/월 | $1.62/월 | **-$9.18** |
| API 호출 | $0 (무료 범위) | $0 (무료 범위) | $0 |
| **총 비용** | **$14.40/월** | **$2.16/월** | **-$12.24 (85% ↓)** |

### 연간 절감액
```
월 $12.24 × 12개월 = 연간 $146.88 절감
```

---

## ✅ JSON 통합 방식의 장점

1. **비용 85% 절감**: $14.40 → $2.16/월
2. **관리 단순화**: 9개 시크릿만 관리
3. **Terraform 코드 간결**: 18개 리소스 (vs 69개)
4. **자동 파싱**: `dataFrom.extract`가 JSON → K8s Secret 자동 변환
5. **백업 용이**: JSON 단위로 관리
6. **버전 관리 효율**: 관련 키들이 함께 버전 관리됨

---

## 🔄 롤백 계획

(기존과 동일, 생략)

---

## 📋 최종 체크리스트

### Terraform 개발
- [ ] 9개 Secret Manager 리소스 (JSON)
- [ ] 9개 ExternalSecret 리소스 (dataFrom.extract)
- [ ] `terraform plan` 성공 (18개 리소스)

### 시크릿 주입
- [ ] JSON 변환 스크립트 작성
- [ ] Dry-run 테스트
- [ ] 실제 주입 (9개 JSON 시크릿)

### ExternalSecret 배포
- [ ] 9개 모두 `SecretSynced`
- [ ] Kubernetes Secret 자동 생성 확인
- [ ] JSON 자동 파싱 검증

### 비용 검증
- [ ] Secret Manager 비용: $0.54/월 확인
- [ ] 버전 누적 후: $2.16/월 예상
- [ ] **85% 비용 절감** 달성

---

## 📚 관련 문서

- [GCP Migration Master Plan](../workload/gcp-migration-master-plan.md)
- [PostgreSQL Migration Guide](../database/postgresql-migration-guide.md)
- [Terraform Resources](../../gcp/terraform/TERRAFORM_RESOURCES.md)

---

**최종 업데이트**: 2025-12-15 (JSON 통합 방식으로 최적화)

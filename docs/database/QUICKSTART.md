# Cloud SQL + Secret Manager 빠른 시작 가이드

**최종 업데이트**: 2025-12-15
**목표**: Secret Manager의 DB credentials로 Cloud SQL 자동 생성

---

## 🎯 전체 흐름

```
1. gcloud CLI로 빈 Secret 생성
   ↓
2. 웹 콘솔에서 실제 비밀번호 입력 (JSON 형식)
   ↓
3. IAM 권한 설정 (Terraform SA에게 읽기 권한)
   ↓
4. Terraform Apply
   - Secret Manager에서 credentials 읽기
   - Cloud SQL 인스턴스 생성
   - DB 사용자 생성 (Secret Manager 비밀번호 사용)
   - Cloud SQL Private IP를 Secret Manager에 자동 업데이트
   ↓
5. External Secrets Operator가 Kubernetes Secret 동기화
   ↓
6. 애플리케이션 Pod가 Cloud SQL 연결
```

---

## ⚡ 빠른 실행

### 1단계: Secret Manager 생성 (1분)

```bash
# 9개 빈 Secret 생성
bash scripts/create-secrets.sh
```

**결과**:
- prod-ojeomneo-db-credentials ✅
- prod-reviewmaps-db-credentials ✅
- prod-ojeomneo-api-credentials ✅
- prod-reviewmaps-api-credentials ✅
- prod-ojeomneo-redis-credentials ✅
- prod-ojeomneo-admin-credentials ✅
- prod-reviewmaps-naver-api-credentials ✅
- prod-monitoring-smtp-credentials ✅
- prod-argocd-dex-credentials ✅

---

### 2단계: 웹 콘솔에서 값 입력 (5분)

#### 2.1. GCP 콘솔 열기
https://console.cloud.google.com/security/secret-manager?project=infra-480802

#### 2.2. prod-ojeomneo-db-credentials 값 입력

1. "prod-ojeomneo-db-credentials" 클릭
2. "NEW VERSION" 버튼 클릭
3. 다음 JSON 붙여넣기:

```json
{
  "POSTGRES_USER": "ojeomneo",
  "POSTGRES_PASSWORD": "rlavhWkdWkdaos!1",
  "POSTGRES_DB": "ojeomneo"
}
```

**⚠️ 중요**: `POSTGRES_SERVER`는 Cloud SQL 생성 **후**에 자동으로 업데이트됩니다. 지금은 넣지 마세요!

4. "ADD NEW VERSION" 버튼 클릭

#### 2.3. prod-reviewmaps-db-credentials 값 입력

1. "prod-reviewmaps-db-credentials" 클릭
2. "NEW VERSION" 버튼 클릭
3. 다음 JSON 붙여넣기:

```json
{
  "POSTGRES_USER": "reviewmaps",
  "POSTGRES_PASSWORD": "Reviewmaps1120$",
  "POSTGRES_DB": "reviewmaps"
}
```

**⚠️ 중요**: `POSTGRES_HOST`는 Cloud SQL 생성 **후**에 자동으로 업데이트됩니다. 지금은 넣지 마세요!

4. "ADD NEW VERSION" 버튼 클릭

#### 2.4. 나머지 7개 Secret 값 입력

- backup_secrets/ 디렉토리의 YAML 파일을 참고하여 JSON 형식으로 변환
- 각 Secret에 "NEW VERSION"으로 추가

---

### 3단계: IAM 권한 설정 (1분)

```bash
# Terraform SA와 External Secrets SA에 읽기 권한 부여
bash scripts/setup-secret-iam.sh
```

**결과**:
- ✅ terraform@infra-480802.iam.gserviceaccount.com → Secret Accessor
- ✅ external-secrets-sa@infra-480802.iam.gserviceaccount.com → Secret Accessor

---

### 4단계: Terraform으로 Cloud SQL 생성 (5-10분)

```bash
cd gcp/terraform/environments/prod

# 초기화
terraform init

# 실행 계획 확인
terraform plan

# 적용
terraform apply
```

**Terraform이 수행하는 작업**:
1. ✅ Secret Manager에서 DB credentials 읽기
2. ✅ Cloud SQL 인스턴스 생성 (PostgreSQL 15)
3. ✅ VPC Peering 설정 (Private IP)
4. ✅ PostgreSQL Extensions 활성화 (pgcrypto, postgis)
5. ✅ Database 생성 (ojeomneo, reviewmaps)
6. ✅ DB 사용자 생성 (Secret Manager 비밀번호 사용)
7. ✅ Secret Manager 업데이트 (POSTGRES_SERVER → Cloud SQL Private IP)

**생성 결과**:
```
Cloud SQL Instance: prod-woohalabs-cloudsql
Private IP: 10.128.0.X
Databases: ojeomneo, reviewmaps
Users: ojeomneo (owner), reviewmaps (owner)
```

---

### 5단계: 연결 확인 (2분)

#### 5.1. Secret Manager 업데이트 확인

```bash
# Cloud SQL Private IP가 자동으로 업데이트되었는지 확인
gcloud secrets versions access latest \
  --secret=prod-ojeomneo-db-credentials \
  --project=infra-480802 | jq .POSTGRES_SERVER
```

**기대 결과**: "10.128.0.X" (PLACEHOLDER → 실제 Private IP로 변경됨)

#### 5.2. Kubernetes Secret 동기화 확인

```bash
# ExternalSecret 상태 확인
kubectl get externalsecrets -n ojeomneo
kubectl get externalsecrets -n reviewmaps

# Kubernetes Secret 생성 확인
kubectl get secret ojeomneo-db-credentials -n ojeomneo
kubectl get secret reviewmaps-db-credentials -n reviewmaps

# Secret 내용 확인
kubectl get secret ojeomneo-db-credentials -n ojeomneo \
  -o jsonpath='{.data.POSTGRES_SERVER}' | base64 -d
```

**기대 결과**: Cloud SQL Private IP가 정상적으로 동기화됨

#### 5.3. Cloud SQL 연결 테스트

```bash
# Cloud SQL Proxy를 통한 연결 테스트
cloud_sql_proxy -instances=infra-480802:asia-northeast3:prod-woohalabs-cloudsql=tcp:5432

# psql 연결
psql -h 127.0.0.1 -U ojeomneo -d ojeomneo
# 비밀번호: rlavhWkdWkdaos!1
```

---

## 🎉 완료!

이제 다음이 자동으로 동작합니다:

✅ **Secret Manager**: DB credentials 중앙 관리
✅ **Cloud SQL**: PostgreSQL 15 인스턴스 실행 중
✅ **Kubernetes Secret**: 자동 동기화 (External Secrets Operator)
✅ **애플리케이션**: Cloud SQL Private IP로 자동 연결

---

## 🧹 정리 작업

### backup_secrets/ 디렉토리 삭제

Secret Manager에 모두 마이그레이션 완료 후:

```bash
# 1. 백업 확인 (다시 복구 불가능하므로 신중하게)
ls -la backup_secrets/

# 2. 삭제
rm -rf backup_secrets/

# 3. Git 커밋
git add .
git commit -m "chore: Remove backup_secrets (migrated to Secret Manager)"
git push
```

### Git 히스토리에서 완전 제거 (선택사항)

만약 backup_secrets/가 이미 Git에 커밋되었다면:

```bash
# BFG Repo-Cleaner 설치
brew install bfg  # macOS
# 또는 https://rtyley.github.io/bfg-repo-cleaner/

# backup_secrets/ 디렉토리 완전 제거
bfg --delete-folders backup_secrets

# Git 정리
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (주의: 협업 시 팀원과 협의 필요)
git push --force
```

---

## 📚 상세 문서

- **Secret Manager 수동 설정**: [secret-manager-setup-manual.md](../security/secret-manager-setup-manual.md)
- **Terraform 통합 가이드**: [terraform-secretmanager-integration.md](./terraform-secretmanager-integration.md)
- **Secret Manager 마이그레이션**: [secret-manager-migration-guide.md](../security/secret-manager-migration-guide.md)
- **PostgreSQL 마이그레이션**: [postgresql-migration-guide.md](./postgresql-migration-guide.md)

---

## ⚠️ 트러블슈팅

### 문제 1: Terraform이 Secret을 읽지 못함

**증상**:
```
Error: Error reading secret version: Permission denied
```

**해결**:
```bash
# IAM 권한 재설정
bash scripts/setup-secret-iam.sh
```

### 문제 2: Cloud SQL 사용자 생성 실패

**증상**:
```
Error: User already exists
```

**해결**:
```bash
# 기존 사용자 삭제 후 재시도
gcloud sql users delete ojeomneo \
  --instance=prod-woohalabs-cloudsql \
  --project=infra-480802

terraform apply
```

### 문제 3: Secret Manager 업데이트 실패

**증상**:
```
Error: jq: command not found
```

**해결**:
```bash
# jq 설치
sudo apt-get update && sudo apt-get install -y jq  # Ubuntu
brew install jq  # macOS
```

---

## 💰 비용 예상

### Secret Manager
- **시크릿 개수**: 9개
- **월 비용**: $0.54 (9 × $0.06)

### Cloud SQL
- **인스턴스**: db-g1-small (1 vCPU, 1.7GB RAM)
- **스토리지**: 20GB SSD
- **월 비용**: ~$27

**총 예상 비용**: ~$27.54/월

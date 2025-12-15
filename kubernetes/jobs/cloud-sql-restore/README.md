# Cloud SQL 데이터베이스 복원 가이드

Cloud SQL PostgreSQL 인스턴스에 백업 데이터를 복원하는 Kubernetes Job 리소스입니다.

## 사전 준비 (Prerequisites)

### 1. GCP Secret Manager 업데이트

각 데이터베이스의 Secret에 `POSTGRES_HOST`와 `POSTGRES_PORT` 추가 필요:

#### Ojeomneo Database

Secret 이름: `prod-ojeomneo-db-credentials`

기존 Secret 내용 확인:

```
gcloud secrets versions access latest --secret=prod-ojeomneo-db-credentials --project=infra-480802
```

업데이트할 JSON 형식:

```json
{
  "POSTGRES_HOST": "10.38.0.3",
  "POSTGRES_PORT": "5432",
  "POSTGRES_USER": "ojeomneo",
  "POSTGRES_PASSWORD": "[기존 비밀번호 유지]",
  "POSTGRES_DB": "ojeomneo"
}
```

업데이트 명령어:

```
# 임시 파일 생성
echo '{
  "POSTGRES_HOST": "10.38.0.3",
  "POSTGRES_PORT": "5432",
  "POSTGRES_USER": "ojeomneo",
  "POSTGRES_PASSWORD": "[기존 비밀번호]",
  "POSTGRES_DB": "ojeomneo"
}' > /tmp/ojeomneo-creds.json

# Secret 업데이트
gcloud secrets versions add prod-ojeomneo-db-credentials \
  --data-file=/tmp/ojeomneo-creds.json \
  --project=infra-480802

# 임시 파일 삭제
rm /tmp/ojeomneo-creds.json
```

#### ReviewMaps Database

Secret 이름: `prod-reviewmaps-db-credentials`

업데이트할 JSON 형식:

```json
{
  "POSTGRES_HOST": "10.38.0.3",
  "POSTGRES_PORT": "5432",
  "POSTGRES_USER": "reviewmaps",
  "POSTGRES_PASSWORD": "[기존 비밀번호 유지]",
  "POSTGRES_DB": "reviewmaps"
}
```

업데이트 명령어:

```
echo '{
  "POSTGRES_HOST": "10.38.0.3",
  "POSTGRES_PORT": "5432",
  "POSTGRES_USER": "reviewmaps",
  "POSTGRES_PASSWORD": "[기존 비밀번호]",
  "POSTGRES_DB": "reviewmaps"
}' > /tmp/reviewmaps-creds.json

gcloud secrets versions add prod-reviewmaps-db-credentials \
  --data-file=/tmp/reviewmaps-creds.json \
  --project=infra-480802

rm /tmp/reviewmaps-creds.json
```

### 2. GCS 버킷 생성 및 SQL 파일 업로드

#### 버킷 생성

```
gsutil mb -p infra-480802 -l asia-northeast3 gs://woohalabs-database-backups
```

#### SQL 파일 업로드

```
cd /path/to/infra
gsutil cp backup_sql/ojeomneo_backup.sql gs://woohalabs-database-backups/backups/ojeomneo_backup.sql
gsutil cp backup_sql/reviewmaps_backup.sql gs://woohalabs-database-backups/backups/reviewmaps_backup.sql
```

#### 파일 확인

```
gsutil ls gs://woohalabs-database-backups/backups/
```

### 3. GCP IAM 권한 설정

Kubernetes ServiceAccount에 GCS 접근 권한 부여:

```
gcloud projects add-iam-policy-binding infra-480802 \
  --member="serviceAccount:cloud-sql-restore-sa@infra-480802.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

## 배포 방법 (Deployment)

### Ojeomneo 데이터베이스 복원

#### 1. Namespace 생성

```
kubectl apply -f ojeomneo/namespace.yaml
```

#### 2. ServiceAccount 생성

```
kubectl apply -f ojeomneo/service-account.yaml
```

#### 3. ExternalSecret 생성

```
kubectl apply -f ojeomneo/external-secret.yaml
```

#### 4. Secret 동기화 확인

```
kubectl get externalsecret -n ojeomneo ojeomneo-db-credentials
kubectl get secret -n ojeomneo ojeomneo-db-credentials
```

#### 5. Job 실행

```
kubectl apply -f ojeomneo/job.yaml
```

#### 6. Job 실행 상태 확인

```
kubectl get job cloud-sql-restore-ojeomneo -n ojeomneo
kubectl get pods -l job-name=cloud-sql-restore-ojeomneo -n ojeomneo
kubectl logs -f job/cloud-sql-restore-ojeomneo -n ojeomneo
```

### ReviewMaps 데이터베이스 복원

동일한 절차를 `reviewmaps/` 디렉토리 파일로 실행:

```
kubectl apply -f reviewmaps/namespace.yaml
kubectl apply -f reviewmaps/service-account.yaml
kubectl apply -f reviewmaps/external-secret.yaml
kubectl apply -f reviewmaps/job.yaml
```

## 트러블슈팅 (Troubleshooting)

### Job 실패 시

#### 1. Pod 로그 확인

```
kubectl logs -f <pod-name> -c download-backup -n default
kubectl logs -f <pod-name> -c restore-database -n default
```

#### 2. 일반적인 문제

| 문제 | 원인 | 해결 방법 |
|------|------|-----------|
| GCS 접근 실패 | IAM 권한 부족 | Workload Identity 설정 확인 |
| DB 연결 실패 | Secret Manager 값 누락 | POSTGRES_HOST, PORT 확인 |
| SQL 복원 실패 | 데이터베이스 이미 존재 | 기존 데이터 백업 후 DROP |
| Timeout | SQL 파일 너무 큼 | Job timeout 증가 |

#### 3. Job 재실행

```
kubectl delete job cloud-sql-restore-ojeomneo -n default
kubectl apply -f ojeomneo/job.yaml
```

#### 4. 수동 복원 (디버깅용)

```
kubectl run -it --rm psql-debug \
  --image=postgres:15-alpine \
  --env="PGHOST=10.38.0.3" \
  --env="PGPORT=5432" \
  --env="PGDATABASE=ojeomneo" \
  --env="PGUSER=ojeomneo" \
  --env="PGPASSWORD=[password]" \
  -- psql
```

## 데이터 검증 (Verification)

### 1. 테이블 개수 확인

```
kubectl run -it --rm psql-check \
  --image=postgres:15-alpine \
  --env="PGHOST=10.38.0.3" \
  --env="PGDATABASE=ojeomneo" \
  --env="PGUSER=ojeomneo" \
  -- psql -c "\dt"
```

### 2. 레코드 개수 확인

```
kubectl run -it --rm psql-check \
  --image=postgres:15-alpine \
  --env="PGHOST=10.38.0.3" \
  --env="PGDATABASE=ojeomneo" \
  --env="PGUSER=ojeomneo" \
  -- psql -c "SELECT COUNT(*) FROM [table_name];"
```

## 정리 (Cleanup)

### 완료된 Job 삭제

```
kubectl delete job cloud-sql-restore-ojeomneo -n default
kubectl delete job cloud-sql-restore-reviewmaps -n default
```

### ExternalSecret 및 Secret 유지

데이터베이스 연결 정보는 애플리케이션에서 계속 사용하므로 삭제하지 않음:

- `ojeomneo-db-credentials` (ExternalSecret + Secret)
- `reviewmaps-db-credentials` (ExternalSecret + Secret)

## 참고 사항 (Notes)

### Cloud SQL Private IP 연결

- Cloud SQL은 Private IP (10.38.0.3)로만 접근 가능
- GKE 클러스터가 동일한 VPC(default)에 있어야 함
- Public IP는 비활성화되어 있음

### Workload Identity

- ServiceAccount는 Workload Identity를 사용하여 GCP IAM과 연동
- GCS 접근을 위해 `roles/storage.objectViewer` 권한 필요
- Secret Manager 접근은 External Secrets Operator가 처리

### 백업 파일 관리

- GCS 버킷: `woohalabs-database-backups`
- 경로: `gs://woohalabs-database-backups/backups/`
- 버전 관리를 위해 타임스탬프 추가 권장: `ojeomneo_backup_20250615.sql`

## 연락처 (Contact)

- 인프라 관련 문의: [DevOps Team]
- GCP 권한 요청: [Cloud Admin]

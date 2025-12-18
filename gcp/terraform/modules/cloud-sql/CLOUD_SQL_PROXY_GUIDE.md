# Cloud SQL Proxy 사용 가이드

Cloud SQL Public IP를 비활성화하고 Private IP 전용으로 운영하기 위한 가이드입니다.

## 변경 사항

**Before**: Public IP + Private IP (모든 IP 접근 가능)
**After**: Private IP 전용 (Cloud SQL Proxy로 로컬 접근)

### 보안 강화 효과
- Public IP 비활성화로 인터넷 노출 방지
- VPC 내부에서만 접근 가능
- Cloud SQL Proxy를 통한 안전한 로컬 연결

## Cloud SQL Proxy 사용 방법

### 1. gcloud CLI를 통한 간편 연결 (권장)

#### ReviewMaps 데이터베이스 연결
```bash
gcloud sql connect prod-woohalabs-cloudsql \
  --user=reviewmaps_user \
  --database=reviewmaps_db \
  --project=infra-480802
```

#### Ojeomneo 데이터베이스 연결
```bash
gcloud sql connect prod-woohalabs-cloudsql \
  --user=ojeomneo_user \
  --database=ojeomneo_db \
  --project=infra-480802
```

**특징**:
- Cloud SQL Proxy 자동 설치 및 실행
- 인증 자동 처리
- 연결 종료 시 Proxy 자동 정리

### 2. Cloud SQL Auth Proxy 직접 사용

#### 설치
```bash
# macOS
brew install cloud-sql-proxy

# Linux
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.linux.amd64
chmod +x cloud-sql-proxy
```

#### 실행
```bash
# Proxy 실행 (백그라운드)
cloud-sql-proxy infra-480802:asia-northeast3:prod-woohalabs-cloudsql \
  --port 5432 &

# PostgreSQL 클라이언트로 연결
psql "host=127.0.0.1 port=5432 dbname=reviewmaps_db user=reviewmaps_user"
```

#### Proxy 종료
```bash
# 실행 중인 Proxy 찾기
ps aux | grep cloud-sql-proxy

# Proxy 종료
kill <PID>
```

### 3. 애플리케이션 연결 (로컬 개발)

#### Python (Django/FastAPI)
```python
# settings.py 또는 config.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': '127.0.0.1',  # Proxy를 통한 연결
        'PORT': '5432',
        'NAME': 'reviewmaps_db',
        'USER': 'reviewmaps_user',
        'PASSWORD': os.environ['DB_PASSWORD'],
    }
}
```

#### Node.js (TypeScript)
```typescript
// db.config.ts
export const dbConfig = {
  host: '127.0.0.1',  // Proxy를 통한 연결
  port: 5432,
  database: 'reviewmaps_db',
  user: 'reviewmaps_user',
  password: process.env.DB_PASSWORD,
};
```

## Kubernetes 클러스터 내 접근 (프로덕션)

### Private IP 직접 연결
클러스터 내부에서는 Cloud SQL의 Private IP로 직접 연결합니다.

**연결 정보**:
- Host: `<private-ip-address>` (Terraform output 확인)
- Port: `5432`
- Database: `reviewmaps_db` 또는 `ojeomneo_db`
- User: Secret Manager에서 가져옴 (ExternalSecret)

**확인 방법**:
```bash
# Cloud SQL Private IP 확인
gcloud sql instances describe prod-woohalabs-cloudsql \
  --format="value(ipAddresses[0].ipAddress)" \
  --project=infra-480802
```

### 애플리케이션 설정 (Kubernetes)
```yaml
# Pod에서 환경변수로 연결
env:
  - name: POSTGRES_HOST
    valueFrom:
      secretKeyRef:
        name: reviewmaps-db-credentials
        key: POSTGRES_SERVER  # Private IP가 저장됨
  - name: POSTGRES_PORT
    value: "5432"
  - name: POSTGRES_DB
    valueFrom:
      secretKeyRef:
        name: reviewmaps-db-credentials
        key: POSTGRES_DB
```

## GitHub Actions에서 접근

### Cloud SQL Proxy를 사용한 CI/CD
```yaml
# .github/workflows/example.yml
jobs:
  migration:
    runs-on: ubuntu-latest
    steps:
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Setup Cloud SQL Proxy
        run: |
          curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.linux.amd64
          chmod +x cloud-sql-proxy
          ./cloud-sql-proxy infra-480802:asia-northeast3:prod-woohalabs-cloudsql \
            --port 5432 &

      - name: Wait for Proxy
        run: sleep 5

      - name: Run Database Migration
        env:
          PGHOST: 127.0.0.1
          PGPORT: 5432
          PGDATABASE: reviewmaps_db
          PGUSER: reviewmaps_user
          PGPASSWORD: ${{ secrets.DB_PASSWORD }}
        run: |
          # Django migration 예시
          python manage.py migrate
```

## 트러블슈팅

### 연결 실패: "connection refused"
```bash
# Proxy가 실행 중인지 확인
ps aux | grep cloud-sql-proxy

# Proxy 재시작
kill <PID>
cloud-sql-proxy infra-480802:asia-northeast3:prod-woohalabs-cloudsql --port 5432 &
```

### 인증 에러: "permission denied"
```bash
# GCP 인증 확인
gcloud auth list

# Application Default Credentials 설정
gcloud auth application-default login
```

### 포트 충돌: "address already in use"
```bash
# 5432 포트 사용 중인 프로세스 확인
lsof -i :5432

# 기존 PostgreSQL 중지 또는 다른 포트 사용
cloud-sql-proxy infra-480802:asia-northeast3:prod-woohalabs-cloudsql --port 5433 &
```

## 참고 자료

- [Cloud SQL Proxy 공식 문서](https://cloud.google.com/sql/docs/postgres/sql-proxy)
- [Private IP 연결 가이드](https://cloud.google.com/sql/docs/postgres/configure-private-ip)
- [Workload Identity 설정](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)

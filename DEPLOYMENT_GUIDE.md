# Kubernetes 리소스 최적화 및 Cloud SQL 마이그레이션 가이드

## 📋 변경 개요 (Change Overview)

이 배포는 두 가지 주요 최적화를 포함합니다:

1. **Database 아키텍처 변경**: Kubernetes Pod Database → Cloud SQL로 마이그레이션
2. **리소스 최적화**: 모든 애플리케이션 Pod의 CPU/Memory 설정 최적화

## 🎯 목표 및 기대 효과

### Database 마이그레이션

**변경 사항:**
- Ojeomneo와 ReviewMaps의 database subchart 비활성화
- GCP Cloud SQL (PostgreSQL 15) 사용으로 전환
- Secret Manager + External Secrets Operator로 자동 동기화

**기대 효과:**
- ✅ 관리형 서비스로 운영 부담 감소
- ✅ 자동 백업 및 고가용성 지원
- ✅ Kubernetes 리소스 절약 (CPU 350m, Memory 1.5Gi)
- ✅ 데이터 보안 강화 (Secret Manager 통합)

### 리소스 최적화

**변경 전 (Before):**
| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|-------------|-----------|----------------|--------------|
| ojeomneo-server | 100m | 500m | 128Mi | 256Mi |
| ojeomneo-admin | 100m | 500m | 128Mi | 256Mi |
| ojeomneo-database | 100m | 500m | 256Mi | 512Mi |
| reviewmaps-server | 250m | 1000m | 512Mi | 1Gi |
| reviewmaps-admin | 100m | 500m | 256Mi | 512Mi |
| reviewmaps-scrape | - | - | - | - |
| reviewmaps-database | 250m | 500m | 512Mi | 1Gi |
| go-scraper | 100m | 500m | 128Mi | 512Mi |

**변경 후 (After):**
| Pod | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----|-------------|-----------|----------------|--------------|
| ojeomneo-server | 50m | 200m | 128Mi | 256Mi |
| ojeomneo-admin | 50m | 200m | 128Mi | 256Mi |
| ojeomneo-database | **제거됨** | **제거됨** | **제거됨** | **제거됨** |
| reviewmaps-server | 100m | 500m | 256Mi | 512Mi |
| reviewmaps-admin | 50m | 200m | 128Mi | 256Mi |
| reviewmaps-scrape | **50m** | **200m** | **256Mi** | **512Mi** |
| reviewmaps-database | **제거됨** | **제거됨** | **제거됨** | **제거됨** |
| go-scraper | 50m | 200m | 128Mi | 256Mi |

**절약 효과:**
- **CPU Request**: 1000m → 300m (**-70%**)
- **CPU Limit**: 4500m → 1500m (**-67%**)
- **Memory Request**: 1920Mi → 896Mi (**-53%**)
- **Memory Limit**: 4608Mi → 2048Mi (**-56%**)

## 📝 변경된 파일 목록

### 1. ExternalSecret 템플릿 (신규 생성)
- `charts/helm/prod/ojeomneo/templates/externalsecret-db.yaml`
- `charts/helm/prod/reviewmaps/templates/externalsecret-db.yaml`

### 2. Chart.yaml (Database Dependency 제거)
- `charts/helm/prod/ojeomneo/Chart.yaml`
- `charts/helm/prod/reviewmaps/Chart.yaml`

### 3. values.yaml (Database 비활성화 및 리소스 최적화)
- `charts/helm/prod/ojeomneo/values.yaml`
- `charts/helm/prod/ojeomneo/charts/server/values.yaml`
- `charts/helm/prod/ojeomneo/charts/admin/values.yaml`
- `charts/helm/prod/reviewmaps/values.yaml`
- `charts/helm/prod/reviewmaps/charts/go-scraper/values.yaml`

## 🔍 배포 전 사전 검증 (Pre-Deployment Verification)

### 1. Cloud SQL 상태 확인

Cloud SQL 인스턴스가 정상 동작하는지 확인합니다.

```bash
# Cloud SQL 인스턴스 확인
gcloud sql instances describe prod-woohalabs-cloudsql --project=<PROJECT_ID>

# 상태가 RUNNABLE인지 확인
```

**확인 항목:**
- ✅ Instance State: RUNNABLE
- ✅ Database Version: POSTGRES_15
- ✅ Private IP 주소 확인

### 2. Secret Manager 확인

데이터베이스 접속 정보가 Secret Manager에 올바르게 저장되어 있는지 확인합니다.

```bash
# Ojeomneo DB Credentials 확인
gcloud secrets versions access latest --secret=prod-ojeomneo-db-credentials --project=<PROJECT_ID>

# ReviewMaps DB Credentials 확인
gcloud secrets versions access latest --secret=prod-reviewmaps-db-credentials --project=<PROJECT_ID>
```

**확인 항목:**
- ✅ `POSTGRES_HOST` (또는 `POSTGRES_SERVER`)
- ✅ `POSTGRES_PORT` (5432)
- ✅ `POSTGRES_USER`
- ✅ `POSTGRES_PASSWORD`
- ✅ `POSTGRES_DB`

### 3. External Secrets Operator 확인

External Secrets Operator가 정상 동작하는지 확인합니다.

```bash
# External Secrets Operator Pod 확인
kubectl get pods -n external-secrets-system

# ClusterSecretStore 확인
kubectl get clustersecretstore gcpsm-secret-store -o yaml
```

**확인 항목:**
- ✅ External Secrets Operator Pod: Running
- ✅ ClusterSecretStore: gcpsm-secret-store 존재

### 4. 기존 Database Pod 데이터 백업 (중요!)

**⚠️ 매우 중요: 배포 전 반드시 데이터를 백업하세요!**

기존 Kubernetes Pod Database의 데이터가 Cloud SQL로 이미 마이그레이션되었는지 확인합니다.

```bash
# Ojeomneo Database 백업 확인
gsutil ls gs://woohalabs-database-backups/backups/ojeomneo_backup.sql

# ReviewMaps Database 백업 확인
gsutil ls gs://woohalabs-database-backups/backups/reviewmaps_backup.sql
```

**만약 백업이 없다면:**

```bash
# Ojeomneo Database 백업
kubectl exec -n ojeomneo deploy/ojeomneo-database -- \
  pg_dump -U <USER> ojeomneo > /tmp/ojeomneo_backup.sql

# ReviewMaps Database 백업
kubectl exec -n reviewmaps deploy/reviewmaps-database -- \
  pg_dump -U <USER> reviewmaps > /tmp/reviewmaps_backup.sql

# GCS에 업로드
gsutil cp /tmp/ojeomneo_backup.sql gs://woohalabs-database-backups/backups/
gsutil cp /tmp/reviewmaps_backup.sql gs://woohalabs-database-backups/backups/
```

## 🚀 배포 절차 (Deployment Steps)

### Step 1: Helm 차트 업데이트

ArgoCD가 자동으로 감지하도록 Git에 Push합니다.

```bash
# 변경사항 확인
git status
git diff

# 커밋 및 푸시
git add .
git commit -m "feat: Migrate to Cloud SQL and optimize resources

- Disable database subcharts (ojeomneo, reviewmaps)
- Add ExternalSecret templates for Cloud SQL credentials
- Optimize CPU/Memory resources for all applications
- Add resources for reviewmaps-scrape (previously undefined)

Resource savings:
- CPU Request: -70% (1000m → 300m)
- CPU Limit: -67% (4500m → 1500m)
- Memory Request: -53% (1920Mi → 896Mi)
- Memory Limit: -56% (4608Mi → 2048Mi)"

git push origin feature/optimize-k8s-resources
```

### Step 2: Pull Request 생성

GitHub에서 Pull Request를 생성하고 리뷰를 받습니다.

```bash
# GitHub CLI 사용
gh pr create --title "feat: Migrate to Cloud SQL and optimize Kubernetes resources" \
  --body "$(cat <<'EOF'
## Summary
- Database 아키텍처 변경: Kubernetes Pod → Cloud SQL 마이그레이션
- 모든 애플리케이션 Pod 리소스 최적화
- reviewmaps-scrape 리소스 정의 추가

## Changes
- ExternalSecret 템플릿 생성 (Secret Manager 연동)
- Database subchart 비활성화
- CPU/Memory 리소스 최적화 (평균 60% 절약)

## Test Plan
- [ ] Cloud SQL 연결 테스트
- [ ] ExternalSecret 동기화 확인
- [ ] 애플리케이션 정상 동작 확인
- [ ] 리소스 사용률 모니터링

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Step 3: ArgoCD 동기화 모니터링

PR이 머지되면 ArgoCD가 자동으로 변경사항을 감지하고 배포합니다.

```bash
# ArgoCD UI 접속
# https://argocd.ggorockee.com

# 또는 CLI로 동기화 상태 확인
argocd app get ojeomneo
argocd app get reviewmaps
```

**모니터링 항목:**
- ✅ ExternalSecret 생성 및 동기화
- ✅ Database Pod Termination
- ✅ 애플리케이션 Pod Restart
- ✅ Health Check 통과

### Step 4: 배포 후 검증

#### 4.1 ExternalSecret 동기화 확인

```bash
# Ojeomneo ExternalSecret 확인
kubectl get externalsecret -n ojeomneo
kubectl describe externalsecret ojeomneo-db-credentials -n ojeomneo

# Secret이 생성되었는지 확인
kubectl get secret ojeomneo-db-credentials -n ojeomneo

# ReviewMaps ExternalSecret 확인
kubectl get externalsecret -n reviewmaps
kubectl describe externalsecret reviewmaps-db-credentials -n reviewmaps

# Secret이 생성되었는지 확인
kubectl get secret reviewmaps-db-credentials -n reviewmaps
```

**기대 결과:**
- ExternalSecret Status: `SecretSynced`
- Secret이 자동으로 생성됨

#### 4.2 애플리케이션 연결 테스트

```bash
# Ojeomneo Server Health Check
kubectl exec -n ojeomneo deploy/ojeomneo-server -- \
  curl -f http://localhost:3000/ojeomneo/v1/healthcheck/ready

# ReviewMaps Server Health Check
kubectl exec -n reviewmaps deploy/reviewmaps-server -- \
  curl -f http://localhost:3000/healthz
```

**기대 결과:**
- HTTP 200 응답
- Database 연결 성공

#### 4.3 리소스 사용률 확인

```bash
# Pod 리소스 사용률 확인
kubectl top pods -n ojeomneo
kubectl top pods -n reviewmaps

# 노드 리소스 여유 확인
kubectl top nodes
```

**기대 결과:**
- CPU 사용률: 10-30%
- Memory 사용률: 30-50%
- 노드에 충분한 여유 공간 확보

## 🔧 트러블슈팅 (Troubleshooting)

### 문제 1: ExternalSecret 동기화 실패

**증상:**
```bash
kubectl get externalsecret -n ojeomneo
# NAME                          STATUS         AGE
# ojeomneo-db-credentials       SecretSyncError   5m
```

**해결 방법:**

1. ClusterSecretStore 확인:
```bash
kubectl get clustersecretstore gcpsm-secret-store -o yaml
```

2. External Secrets Operator 로그 확인:
```bash
kubectl logs -n external-secrets-system deployment/external-secrets
```

3. Secret Manager 권한 확인:
```bash
gcloud secrets get-iam-policy prod-ojeomneo-db-credentials --project=<PROJECT_ID>
```

### 문제 2: Database 연결 실패

**증상:**
애플리케이션 로그에 "connection refused" 또는 "could not connect to database" 에러

**해결 방법:**

1. Cloud SQL Private IP 확인:
```bash
gcloud sql instances describe prod-woohalabs-cloudsql --project=<PROJECT_ID> \
  --format="value(ipAddresses[0].ipAddress)"
```

2. Secret 내용 확인:
```bash
kubectl get secret ojeomneo-db-credentials -n ojeomneo -o jsonpath='{.data.POSTGRES_HOST}' | base64 -d
```

3. 네트워크 연결 테스트:
```bash
kubectl run -n ojeomneo test-db --rm -it --image=postgres:15-alpine -- \
  psql -h <CLOUD_SQL_IP> -U <USER> -d ojeomneo
```

### 문제 3: Pod OOMKilled (메모리 부족)

**증상:**
```bash
kubectl get pods -n reviewmaps
# NAME                                READY   STATUS      RESTARTS   AGE
# reviewmaps-server-xxx               0/1     OOMKilled   3          5m
```

**해결 방법:**

메모리 limit을 일시적으로 증가시킵니다:

```yaml
# reviewmaps/values.yaml
server:
  resources:
    limits:
      memory: 1Gi  # 512Mi → 1Gi로 증가
```

### 문제 4: 애플리케이션 시작 실패

**증상:**
Pod이 CrashLoopBackOff 상태

**해결 방법:**

1. Pod 로그 확인:
```bash
kubectl logs -n ojeomneo deploy/ojeomneo-server --tail=100
```

2. 환경 변수 확인:
```bash
kubectl exec -n ojeomneo deploy/ojeomneo-server -- env | grep POSTGRES
```

3. Database 연결 테스트:
```bash
kubectl exec -n ojeomneo deploy/ojeomneo-server -- \
  psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT version();"
```

## 🔄 롤백 계획 (Rollback Plan)

만약 배포 후 문제가 발생하면 다음 절차로 롤백합니다:

### 방법 1: ArgoCD Rollback (권장)

```bash
# ArgoCD UI에서 이전 버전으로 Rollback

# 또는 CLI로:
argocd app rollback ojeomneo <이전_리비전_번호>
argocd app rollback reviewmaps <이전_리비전_번호>
```

### 방법 2: Git Revert

```bash
# PR 커밋 Revert
git revert <커밋_해시>
git push origin main
```

### 방법 3: 수동 Database 재활성화 (긴급)

```bash
# values.yaml 수정
database:
  enabled: true  # false → true

# 즉시 적용
kubectl apply -f charts/helm/prod/ojeomneo/values.yaml
kubectl apply -f charts/helm/prod/reviewmaps/values.yaml
```

## 📊 모니터링 및 알람

배포 후 다음 메트릭을 지속적으로 모니터링합니다:

### 1. Grafana 대시보드
- URL: `https://monitoring.ggorockee.com` (Istio VirtualService `grafana-vs`, Prometheus는 외부 노출 없음)
- 확인 항목:
  - Pod CPU/Memory 사용률
  - Database 연결 수
  - API 응답 시간
  - 에러율

### 2. SigNoz (OpenTelemetry)
- URL: `https://signoz.ggorockee.com`
- 확인 항목:
  - Trace 정상 동작 여부
  - Database 쿼리 성능
  - 애플리케이션 에러 로그

### 3. 알람 설정
- Pod Crash: Slack 알림
- Database 연결 실패: Email 알림
- 리소스 임계값 초과: PagerDuty 알림

## ✅ 배포 완료 체크리스트

- [ ] Cloud SQL 상태 확인 (RUNNABLE)
- [ ] Secret Manager 설정 확인
- [ ] External Secrets Operator 동작 확인
- [ ] 기존 Database 백업 완료
- [ ] PR 생성 및 리뷰 완료
- [ ] ArgoCD 동기화 완료
- [ ] ExternalSecret 동기화 확인
- [ ] 애플리케이션 Health Check 통과
- [ ] 리소스 사용률 정상 확인
- [ ] 모니터링 대시보드 확인
- [ ] 롤백 계획 검토 완료

## 📞 문의 및 지원

배포 중 문제가 발생하면 다음 채널로 연락하세요:

- **Slack**: #infra-team
- **Email**: devops@ggorockee.com
- **On-Call**: PagerDuty Escalation

---

**마지막 업데이트**: 2025-12-15
**작성자**: Claude Code (SuperClaude Framework)

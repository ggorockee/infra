# GCP 프로젝트 이관 가이드

## 이관 개요

| 항목 | 기존 | 신규 |
|------|------|------|
| Project ID | `yango-495502` | `yango-501407` |
| 소유 계정 | `woohalabs4@gmail.com` | `woohalabs10@gmail.com` |
| TF State 버킷 | `yango-495502-tfstate` | `yango-501407-tfstate` |
| 리전 | `asia-northeast3` | `asia-northeast3` (동일) |

이 문서는 이전(구 프로젝트 → `yango-495502`) 이관 때 작성되었던 문서를 이번 이관(`yango-495502` → `yango-501407`) 기준으로 갱신한 버전입니다.

## 이관 체크리스트

### Phase 0 - 새 프로젝트 사전 준비 (콘솔/gcloud)

- [x] 새 프로젝트에 결제 계정 연결 (`019BE5-B9EFB8-C3E4D3`)
- [x] 필수 API 활성화 (아래 목록)
- [x] Terraform 서비스 계정 생성 및 권한 부여 (`roles/owner`)
- [x] GCS 버킷 생성 (Terraform state용, 버전관리 활성화)
- [x] 서비스 계정 키 다운로드 (스크래치패드에 보관, GitHub Secrets 등록 후 로컬 파일 삭제 예정)

#### 활성화 필요 API 목록

| API | 설명 |
|-----|------|
| `compute.googleapis.com` | VPC, NAT, Firewall |
| `container.googleapis.com` | GKE |
| `sqladmin.googleapis.com` | Cloud SQL |
| `servicenetworking.googleapis.com` | VPC Peering (Cloud SQL Private IP) |
| `secretmanager.googleapis.com` | Secret Manager |
| `iam.googleapis.com` | IAM |
| `cloudresourcemanager.googleapis.com` | 프로젝트 관리 |
| `iamcredentials.googleapis.com` | Workload Identity |
| `storage.googleapis.com` | GCS (TF state) |
| `dns.googleapis.com` | Cloud DNS |
| `logging.googleapis.com` | 로깅 |
| `monitoring.googleapis.com` | 모니터링 |

### Phase 1 - Terraform 인프라 배포

- [x] 코드 변경 (아래 "코드 변경 사항 요약" 참고)
- [ ] GitHub Repository Secrets 업데이트
  - `GCP_PROJECT_ID` → `yango-501407`
  - `GCP_SA_KEY` → 새 서비스 계정 키 내용 (JSON)
- [ ] feature 브랜치 PR → main 머지
- [ ] GitHub Actions `gcp-terraform-apply` 워크플로우 성공 확인
- [ ] 신규 GKE 클러스터 접근 확인

**배포되는 리소스:**

| 모듈 | 리소스 | 예상 소요 |
|------|--------|---------|
| networking | Default VPC 활용 (Custom VPC 아님) | ~1분 |
| gke | GKE Standard + Spot Node Pool (medium/large) | ~8분 |
| cloud_sql | Cloud SQL PostgreSQL 15 (`prod-woohalabs-cloudsql`) | ~5분 |
| external_secrets | External Secrets Operator + Workload Identity SA | ~3분 |
| cloud_armor | WAF Security Policy | ~1분 |

### Phase 2 - Secret Manager 시크릿 이관

- [ ] 기존 프로젝트 시크릿 목록 확인 (`gcloud secrets list --project=yango-495502`)
- [ ] 새 프로젝트에 시크릿 재등록

**이관 대상 시크릿 (총 18개, 코드 스캔 기준 — 이전 문서엔 15개만 기재되어 있었음):**

| 시크릿 이름 | 용도 |
|------------|------|
| `argocd-dex-google-client-id` | ArgoCD Google OAuth Client ID |
| `argocd-dex-google-client-secret` | ArgoCD Google OAuth Client Secret |
| `argocd-admin-password` | ArgoCD 관리자 비밀번호 |
| `argocd-admin-emails` | ArgoCD 관리자 이메일 목록 |
| `prod-argocd-dex-credentials` | ArgoCD Dex 통합 자격증명 |
| `prod-ojeomneo-db-credentials` | Ojeomneo DB 연결 정보 |
| `prod-ojeomneo-api-credentials` | Ojeomneo API 키 |
| `prod-ojeomneo-redis-credentials` | Ojeomneo Redis 비밀번호 |
| `prod-ojeomneo-admin-credentials` | Ojeomneo Django 설정 |
| `prod-reviewmaps-db-credentials` | ReviewMaps DB 연결 정보 |
| `prod-reviewmaps-api-credentials` | ReviewMaps API 키 |
| `prod-reviewmaps-naver-api-credentials` | ReviewMaps Naver API 키 |
| `hotsao-app-secrets` | Hotsao 앱 시크릿 |
| `prod-hotsao-credentials` | Hotsao Go Scraper 자격증명 |
| `cert-manager-dns01-key` | Cert-Manager DNS-01 Challenge 키 |
| `prod-sybot-credentials` | Sybot 앱 자격증명 (신규 추가분) |
| `prod-yangobot-credentials` | Yangobot 앱 자격증명 (신규 추가분) |
| `prod-monitoring-smtp-credentials` | Grafana SMTP 알림 자격증명 (신규 추가분) |

명령어 패턴:
- 전체 목록 확인: `gcloud secrets list --project=yango-495502`
- 값 확인: `gcloud secrets versions access latest --secret=[SECRET_NAME] --project=yango-495502`
- 새 프로젝트에 생성: `gcloud secrets create [SECRET_NAME] --project=yango-501407`
- 값 등록: `echo -n "[VALUE]" | gcloud secrets versions add [SECRET_NAME] --data-file=- --project=yango-501407`

### Phase 3 - Cloud SQL 데이터 이관

- [ ] 기존 Cloud SQL에서 pg_dump 실행
- [ ] 신규 Cloud SQL에 restore
- [ ] 데이터 정합성 확인

**이관 절차:**

1. Cloud SQL Auth Proxy로 기존 DB 연결: `cloud-sql-proxy yango-495502:asia-northeast3:prod-woohalabs-cloudsql`
2. pg_dump 실행
   - `pg_dump -h 127.0.0.1 -U ojeomneo_user ojeomneo > ojeomneo_backup.sql`
   - `pg_dump -h 127.0.0.1 -U reviewmaps_user reviewmaps > reviewmaps_backup.sql`
3. 새 Cloud SQL Auth Proxy 연결: `cloud-sql-proxy yango-501407:asia-northeast3:prod-woohalabs-cloudsql`
4. restore 실행 (reviewmaps는 `pgcrypto`, `postgis` 확장 선설치 필요)
   - `psql -h 127.0.0.1 -U ojeomneo_user ojeomneo < ojeomneo_backup.sql`
   - `psql -h 127.0.0.1 -U reviewmaps_user reviewmaps < reviewmaps_backup.sql`

참고: `kubernetes/jobs/cloud-sql-restore/{ojeomneo,reviewmaps}/`에 지난 이관 때 쓰던 Job 매니페스트가 남아있음 (Workload Identity 기반 restore). 이번에도 동일 패턴 재사용 가능하나 `service-account.yaml`의 `iam.gke.io/gcp-service-account` 어노테이션이 옛 프로젝트(`infra-480802`)를 가리키고 있어 새 프로젝트 기준으로 SA를 다시 만들고 어노테이션도 갱신해야 함.

### Phase 4 - 워크로드 이관

- [ ] 새 GKE 클러스터 kubeconfig 설정
- [ ] ArgoCD 수동 배포 (첫 번째 설치)
- [ ] ArgoCD에 Git 저장소 연결
- [ ] ApplicationSets 적용 → 앱 자동 배포 (ojeomneo, reviewmaps, hotsao, sybot, yangobot 포함 여부 확인)
- [ ] Istio Ingress Gateway IP 확인

**ArgoCD 초기 배포:**

- kubeconfig: `gcloud container clusters get-credentials woohalabs-prod-gke --region=asia-northeast3 --project=yango-501407`
- 설치: `helm upgrade --install argo-cd argo/argo-cd -n argocd --create-namespace -f charts/helm/prod/argo-cd/values.yaml`

이후 ArgoCD가 나머지 앱들(Istio, cert-manager, 애플리케이션들)을 자동으로 배포.

### Phase 5 - DNS 전환 및 검증

- [ ] 새 Istio Ingress Gateway 외부 IP 확인
- [ ] DNS 레코드를 새 IP로 변경 (TTL 낮춤 → 전환 → 확인 후 TTL 복원)
- [ ] HTTPS 인증서 발급 확인
- [ ] 각 앱 정상 동작 확인 (ojeomneo, reviewmaps, hotsao, sybot, yangobot)
- [ ] 모니터링 스택 확인 (Prometheus, Grafana, Loki, SigNoz)

**검증 체크리스트:**

| 서비스 | 확인 방법 |
|--------|---------|
| ArgoCD | 로그인 확인 |
| Ojeomneo | 앱 정상 동작 |
| ReviewMaps | 앱 정상 동작 |
| Hotsao | 앱 정상 동작 |
| Sybot | 앱 정상 동작 |
| Yangobot | 앱 정상 동작 |
| Grafana | 대시보드 확인 |

### Phase 6 - 기존 프로젝트 정리

- [ ] 전체 서비스 정상 확인 후 7일 유지
- [ ] 기존 Cloud SQL 최종 백업
- [ ] 기존 프로젝트(`yango-495502`) 리소스 삭제 또는 프로젝트 종료

---

## 코드 변경 사항 요약

### 변경된 파일

| 파일 | 변경 내용 |
|------|---------|
| `gcp/terraform/environments/prod/variables.tf` | `project_id` 기본값을 `yango-501407`로 변경 |
| `gcp/terraform/environments/prod/backend.tf` | TF State GCS 버킷명을 `yango-501407-tfstate`로 변경 |
| `charts/helm/prod/cert-manager/values.yaml` | `clusterIssuer.gcpProjectId`를 `yango-501407`로 변경 (Cloud DNS-01 solver) |
| `charts/helm/prod/kube-prometheus-stack/values-override.yaml` | `clusterSecretStore.gcpProjectID`, `gcpServiceAccount`를 `yango-501407` 기준으로 변경 (기존에 `infra-480802`로 남아있던 죽은 참조 정리, 현재 `enabled: false`로 Terraform이 관리하므로 실동작에는 영향 없음) |
| `charts/helm/prod/argo-cd/values.yaml` | `serviceAccount.annotations`의 `iam.gke.io/gcp-service-account`를 `argocd-prod@yango-501407.iam.gserviceaccount.com`으로 변경 (기존 `infra-480802` 참조는 Workload Identity 바인딩이 실제로 깨져 있던 값이었음) |

### GitHub Actions Secrets 변경 필요

GitHub Repository → Settings → Secrets and variables → Actions:

| Secret 이름 | 변경 내용 |
|------------|---------|
| `GCP_PROJECT_ID` | `yango-501407` 로 업데이트 |
| `GCP_SA_KEY` | 새 프로젝트 서비스 계정 키 JSON으로 업데이트 |

---

## 주의사항

- Cloud SQL `deletion_protection = true` 설정으로 실수 삭제 방지됨
- 데이터 이관 시 서비스 다운타임 발생 (DB migration 단계)
- Spot 노드 사용으로 이관 중 노드 회수 가능성 있음 (GKE 배포 시 주의)
- Workload Identity 바인딩은 Terraform apply 시 자동 설정됨 (`external-secrets-prod@`, `argocd-prod@` SA)
- `kubernetes/jobs/cloud-sql-restore/*/service-account.yaml`은 Terraform 미관리 리소스라 수동으로 새 프로젝트 SA를 만들고 어노테이션을 갱신해야 함

## 최종 업데이트

- 작성일: 2026-02-17 (구 → yango-495502 이관 기준)
- 갱신일: 2026-07-04 (yango-495502 → yango-501407 이관 기준)
- 이관 대상 프로젝트: `yango-501407`

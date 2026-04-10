# GCP 프로젝트 이관 가이드

## 이관 개요

| 항목 | 기존 | 신규 |
|------|------|------|
| Project ID | `infra-480802` | `project-2372300d-c493-447b-8ee` |
| TF State 버킷 | `woohalabs-terraform-state` | `project-2372300d-tfstate` |
| 리전 | `asia-northeast3` | `asia-northeast3` (동일) |

## 이관 체크리스트

### Phase 0 - 새 프로젝트 사전 준비 (콘솔/gcloud)

- [ ] 새 프로젝트에 결제 계정 연결
- [ ] 필수 API 활성화 (아래 목록)
- [ ] Terraform 서비스 계정 생성 및 권한 부여
- [ ] GCS 버킷 생성 (Terraform state용)
- [ ] 서비스 계정 키 다운로드

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

#### gcloud 명령 모음 (참고용)

새 프로젝트에서 실행할 gcloud 명령들:

- API 일괄 활성화: `gcloud services enable [api] --project=project-2372300d-c493-447b-8ee`
- SA 생성: `gcloud iam service-accounts create terraform-sa --project=project-2372300d-c493-447b-8ee`
- SA 권한: `gcloud projects add-iam-policy-binding project-2372300d-c493-447b-8ee --member="serviceAccount:terraform-sa@project-2372300d-c493-447b-8ee.iam.gserviceaccount.com" --role=roles/owner`
- GCS 버킷: `gcloud storage buckets create gs://project-2372300d-tfstate --project=project-2372300d-c493-447b-8ee --location=asia-northeast3`
- SA 키 생성: `gcloud iam service-accounts keys create terraform-key.json --iam-account=terraform-sa@project-2372300d-c493-447b-8ee.iam.gserviceaccount.com`

### Phase 1 - Terraform 인프라 배포

- [ ] GitHub Repository Secrets 업데이트
  - `GCP_PROJECT_ID` → `project-2372300d-c493-447b-8ee`
  - `GCP_SA_KEY` → 새 서비스 계정 키 내용 (JSON)
- [ ] feature 브랜치 생성 후 PR → main 머지
- [ ] GitHub Actions `gcp-terraform-apply` 워크플로우 성공 확인
- [ ] 신규 GKE 클러스터 접근 확인

**배포되는 리소스:**

| 모듈 | 리소스 | 예상 소요 |
|------|--------|---------|
| networking | VPC, Subnet, Router, NAT, Firewall | ~2분 |
| gke | GKE Cluster + Node Pools | ~8분 |
| cloud_sql | Cloud SQL PostgreSQL 15 | ~5분 |
| external_secrets | External Secrets Operator | ~3분 |
| cloud_armor | WAF Security Policy | ~1분 |

### Phase 2 - Secret Manager 시크릿 이관

- [ ] 기존 프로젝트 시크릿 목록 확인
- [ ] 새 프로젝트에 시크릿 재등록

**이관 대상 시크릿 (총 15개):**

| 시크릿 이름 | 용도 |
|------------|------|
| `argocd-dex-google-client-id` | ArgoCD Google OAuth Client ID |
| `argocd-dex-google-client-secret` | ArgoCD Google OAuth Client Secret |
| `argocd-admin-password` | ArgoCD 관리자 비밀번호 |
| `argocd-admin-emails` | ArgoCD 관리자 이메일 목록 |
| `prod-argocd-dex-credentials` | ArgoCD Dex 통합 자격증명 |
| `prod-ojeomneo-db-credentials` | Ojeomneo DB 연결 정보 (HOST, PORT, USER, PASSWORD, DB) |
| `prod-ojeomneo-api-credentials` | Ojeomneo API 키 (JWT, Gemini, OpenAI, Apple, Firebase 등) |
| `prod-ojeomneo-redis-credentials` | Ojeomneo Redis 비밀번호 |
| `prod-ojeomneo-admin-credentials` | Ojeomneo Django 설정 (SECRET_KEY 등) |
| `prod-reviewmaps-db-credentials` | ReviewMaps DB 연결 정보 |
| `prod-reviewmaps-api-credentials` | ReviewMaps API 키 (JWT, Kakao, Google, Apple, Firebase 등) |
| `prod-reviewmaps-naver-api-credentials` | ReviewMaps Naver API 키 (지도, 검색 등) |
| `hotsao-app-secrets` | Hotsao 앱 시크릿 (Redis, RabbitMQ 등) |
| `prod-hotsao-credentials` | Hotsao Go Scraper 자격증명 |
| `cert-manager-dns01-key` | Cert-Manager DNS-01 Challenge 키 |

기존 프로젝트 시크릿 전체 목록 확인:
`gcloud secrets list --project=infra-480802`

각 시크릿 값 확인 후 새 프로젝트에 동일한 이름으로 생성:
`gcloud secrets versions access latest --secret=[SECRET_NAME] --project=infra-480802`
`gcloud secrets create [SECRET_NAME] --project=project-2372300d-c493-447b-8ee`
`echo -n "[VALUE]" | gcloud secrets versions add [SECRET_NAME] --data-file=- --project=project-2372300d-c493-447b-8ee`

### Phase 3 - Cloud SQL 데이터 이관

- [ ] 기존 Cloud SQL에서 pg_dump 실행
- [ ] 신규 Cloud SQL에 restore
- [ ] 데이터 정합성 확인

**이관 절차:**

1. Cloud SQL Auth Proxy로 기존 DB 연결
   - `cloud-sql-proxy infra-480802:asia-northeast3:prod-woohalabs-cloudsql`
2. pg_dump 실행
   - `pg_dump -h 127.0.0.1 -U ojeomneo_user ojeomneo > ojeomneo_backup.sql`
   - `pg_dump -h 127.0.0.1 -U reviewmaps_user reviewmaps > reviewmaps_backup.sql`
3. 새 Cloud SQL Auth Proxy 연결
   - `cloud-sql-proxy project-2372300d-c493-447b-8ee:asia-northeast3:prod-woohalabs-cloudsql`
4. restore 실행
   - `psql -h 127.0.0.1 -U ojeomneo_user ojeomneo < ojeomneo_backup.sql`
   - `psql -h 127.0.0.1 -U reviewmaps_user reviewmaps < reviewmaps_backup.sql`

### Phase 4 - 워크로드 이관

- [ ] 새 GKE 클러스터 kubeconfig 설정
- [ ] ArgoCD 수동 배포 (첫 번째 설치)
- [ ] ArgoCD에 Git 저장소 연결
- [ ] ApplicationSets 적용 → 앱 자동 배포
- [ ] Istio Ingress Gateway IP 확인

**ArgoCD 초기 배포:**

새 GKE 클러스터 kubeconfig 가져오기:
`gcloud container clusters get-credentials woohalabs-prod-gke --region=asia-northeast3 --project=project-2372300d-c493-447b-8ee`

ArgoCD 설치 (기존 Helm values 사용):
`helm upgrade --install argo-cd argo/argo-cd -n argocd --create-namespace -f charts/helm/prod/argo-cd/values.yaml`

이후 ArgoCD가 나머지 앱들(Istio, cert-manager, 애플리케이션들)을 자동으로 배포.

### Phase 5 - DNS 전환 및 검증

- [ ] 새 Istio Ingress Gateway 외부 IP 확인
- [ ] DNS 레코드를 새 IP로 변경 (TTL 낮춤 → 전환 → 확인 후 TTL 복원)
- [ ] HTTPS 인증서 발급 확인
- [ ] 각 앱 정상 동작 확인
- [ ] 모니터링 스택 확인 (Prometheus, Grafana, Loki)

**검증 체크리스트:**

| 서비스 | URL | 확인 방법 |
|--------|-----|---------|
| ArgoCD | argocd.ggorockee.com | 로그인 확인 |
| Ojeomneo | 해당 도메인 | 앱 정상 동작 |
| ReviewMaps | 해당 도메인 | 앱 정상 동작 |
| Grafana | 모니터링 URL | 대시보드 확인 |

### Phase 6 - 기존 프로젝트 정리

- [ ] 전체 서비스 정상 확인 후 7일 유지
- [ ] 기존 Cloud SQL 최종 백업
- [ ] 기존 프로젝트 리소스 삭제 또는 프로젝트 종료

---

## 코드 변경 사항 요약

### 변경된 파일

| 파일 | 변경 내용 |
|------|---------|
| `gcp/terraform/environments/prod/variables.tf` | `project_id` 기본값 변경 |
| `gcp/terraform/environments/prod/backend.tf` | TF State GCS 버킷명 변경 |

### GitHub Actions Secrets 변경 필요

GitHub Repository → Settings → Secrets and variables → Actions:

| Secret 이름 | 변경 내용 |
|------------|---------|
| `GCP_PROJECT_ID` | `project-2372300d-c493-447b-8ee` 로 업데이트 |
| `GCP_SA_KEY` | 새 프로젝트 서비스 계정 키 JSON으로 업데이트 |

---

## 주의사항

- Cloud SQL `deletion_protection = true` 설정으로 실수 삭제 방지됨
- 데이터 이관 시 서비스 다운타임 발생 (DB migration 단계)
- Spot 노드 사용으로 이관 중 노드 회수 가능성 있음 (GKE 배포 시 주의)
- Workload Identity 바인딩은 Terraform apply 시 자동 설정됨

## 최종 업데이트

- 작성일: 2026-02-17
- 이관 대상 프로젝트: `project-2372300d-c493-447b-8ee`

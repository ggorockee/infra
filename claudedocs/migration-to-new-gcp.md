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
- [x] GitHub Repository Secrets 업데이트
  - `GCP_PROJECT_ID` → `yango-501407`
  - `GCP_SA_KEY` → 새 서비스 계정 키 내용 (JSON)
- [x] feature 브랜치 PR → main 머지 (#1096, #1097, #1098)
- [x] GitHub Actions `gcp-terraform-apply` 워크플로우 성공 확인
- [x] 신규 GKE 클러스터 접근 확인

**실행 중 발견된 이슈**: `external_secrets` 모듈(kubernetes_manifest 리소스)은 GKE 클러스터가 이미 떠 있어야 REST client를 구성할 수 있는데, 최초 apply에서는 GKE도 함께 생성되므로 plan이 실패함. 최초 apply에서는 해당 모듈을 비활성화하고, GKE 생성 완료 후 별도 PR(#1097)로 재활성화하는 2단계 부트스트랩으로 처리함. 그 과정에서 External Secrets Operator CRD도 Helm 릴리스와 별개로 먼저 설치해야 하는 동일한 순서 문제가 있어 CRD만 먼저 적용 후 소유권 라벨을 붙여 Helm이 입양하도록 처리함.

**배포되는 리소스:**

| 모듈 | 리소스 | 예상 소요 |
|------|--------|---------|
| networking | Default VPC 활용 (Custom VPC 아님) | ~1분 |
| gke | GKE Standard + Spot Node Pool (medium/large) | ~8분 |
| cloud_sql | Cloud SQL PostgreSQL 15 (`prod-woohalabs-cloudsql`) | ~5분 |
| external_secrets | External Secrets Operator + Workload Identity SA | ~3분 |
| cloud_armor | WAF Security Policy | ~1분 |

### Phase 2 - Secret Manager 시크릿 이관

- [x] 기존 프로젝트 시크릿 목록 확인 (`gcloud secrets list --project=yango-495502`)
- [x] 새 프로젝트에 시크릿 재등록

**실제로는 13개만 존재했음** (아래 표는 코드 스캔 기준 예상 목록이며, `argocd-dex-google-client-id/secret`, `argocd-admin-password`, `argocd-admin-emails`는 `prod-argocd-dex-credentials` 하나로 통합되어 있었고, `prod-sybot-credentials`는 아직 생성된 적이 없었음). 실제 목록 기준 13개를 그대로 이관함.

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

- [x] 기존 Cloud SQL에서 export 실행
- [x] 신규 Cloud SQL에 import
- [x] 데이터 정합성 확인 (export 후 재검증용으로 새 인스턴스에서 다시 export하여 파일 크기 바이트 단위 일치 확인)

**실제로 사용한 절차** (계획했던 Cloud SQL Auth Proxy + pg_dump/psql 대신, 네트워크 접근 불필요한 서버사이드 export/import 사용):

1. `gcloud sql export sql prod-woohalabs-cloudsql gs://[BUCKET]/[DB].sql --database=[DB] --project=yango-495502`
2. GCS 버킷에 대해 새 프로젝트 Cloud SQL 서비스 계정에 `storage.objectViewer` 임시 부여
3. `gcloud sql import sql prod-woohalabs-cloudsql gs://[BUCKET]/[DB].sql --database=[DB] --project=yango-501407`
4. 검증 후 임시 버킷/권한 정리

**실행 중 발견된 이슈**:

- 이관 대상 DB가 계획에는 `ojeomneo`, `reviewmaps` 2개였으나, 실제로는 **`hotsao` DB가 하나 더 존재**했음 (Terraform 미관리, 수동 생성분). 위 절차와 동일하게 추가로 이관하고 `gcloud sql databases create hotsao`, `gcloud sql users create hotsao`로 신규 인스턴스에 사전 생성함.
- `gcp/terraform/modules/cloud-sql/main.tf`의 `null_resource.update_ojeomneo_secret` / `update_reviewmaps_secret`가 Secret Manager의 `POSTGRES_SERVER` 필드만 새 Private IP로 갱신하고, 앱이 실제로 사용하는 `POSTGRES_HOST` 필드는 갱신하지 않아서 이관 후에도 앱이 옛 프로젝트의 Cloud SQL Private IP로 연결을 시도하는 버그를 발견함 (ojeomneo, reviewmaps 둘 다 영향). PR #1098로 코드 수정, 이미 존재하는 시크릿은 수동으로 패치. `hotsao-app-secrets`의 `DB_HOST`도 동일한 문제라 같이 수동 패치함.

### Phase 4 - 워크로드 이관

- [x] 새 GKE 클러스터 kubeconfig 설정
- [x] ArgoCD 수동 배포 (첫 번째 설치, 사용자가 직접 진행)
- [x] ArgoCD에 Git 저장소 연결
- [x] ApplicationSets 적용 → 앱 자동 배포 (ojeomneo, reviewmaps, hotsao, istio, cert-manager, gke-backendconfig, gke-storageclass, woohalabs-app-ads, yangobot — 12개 Application 전부 Synced)
- [x] Istio Ingress Gateway IP 확인 → `34.64.94.80`

**실행 중 발견/해결한 이슈**:

- `istio-ingressgateway` 파드가 istiod의 sidecar-injector webhook이 준비되기 전에 스케줄되어 `image: auto` 상태로 ImagePullBackOff 발생. 파드 삭제로 재생성하여 정상 이미지(`proxyv2`)로 교체됨.
- `istio-gateway-config`의 `grafana-vs`, `prometheus-vs` VirtualService가 `monitoring` 네임스페이스를 참조하는데, 모니터링 스택(kube-prometheus-stack) 자체가 저장소에서 의도적으로 비활성화되어 있어 네임스페이스가 없어 동기화 실패. `monitoring` 네임스페이스만 생성해서 해결 (모니터링 앱 자체를 재활성화하는 것은 이번 범위 밖).
- `argocd-rbac-policy` ExternalSecret이 `creationPolicy: Merge`로 존재하지 않는 Secret `argocd-rbac-cm`에 병합을 시도하다 `SecretSyncedError` 발생. 이관 이전부터 있던 차트 설정 이슈로 보이며, 이번 이관 범위에서는 수정하지 않고 발견 사항으로만 기록.
- `hotsao`의 cron 파드들이 일시적으로 `Insufficient cpu`로 Pending (전체 앱이 동시에 최초 부트스트랩되며 발생한 일시적 현상, `spot_pool_large`가 2→3 노드로 오토스케일되며 자연 해소됨).

### Phase 5 - DNS 전환 및 검증 — **부분 완료 (실제 트래픽 전환은 아직 안 됨)**

- [x] 새 Istio Ingress Gateway 외부 IP 확인 (`34.64.94.80`)
- [x] Cloud DNS 존 5개(`ggorockee-com`, `ggorockee-org`, `hotsao-com`, `review-maps-com`, `woohalabs-com`)를 `yango-501407`에 생성, A레코드(root+wildcard)를 새 IP로 설정
- [x] HTTPS 인증서 발급 확인 (ggorockee.com, hotsao.com, review-maps.com, woohalabs.com 4개 모두 발급 완료)
- [x] 각 앱 정상 동작 확인 (ojeomneo, reviewmaps, hotsao — 클러스터 내부에서 파드/DB 연결 기준. sybot/yangobot은 파드 Healthy 확인, 도메인 통한 외부 접근은 미검증)
- [ ] 모니터링 스택 확인 — **해당 없음**: Prometheus/Grafana/Loki는 저장소에서 의도적으로 비활성화된 상태 (`charts/argocd/configurations/prod/legacy/monitoring-kube-prometheus-stack.yaml.monitoring`, PR #1035에서 제거). 이관과 무관한 기존 상태.
- [ ] **DNS 레코드 실제 전환 (레지스트라/Cloudflare 레벨) — 미실행**

**중요**: 각 도메인의 실제 권위 DNS는 Google Cloud DNS가 아니라 **Cloudflare**임 (`isaac.ns.cloudflare.com`, `hope.ns.cloudflare.com`). 위에서 만든 `yango-501407`의 Cloud DNS 존은 실제 트래픽에는 전혀 영향을 주지 않으며, 오직 `_acme-challenge.<domain>` 서브도메인만 Cloudflare에서 Google Cloud DNS로 NS 위임되어 있어 (사용자가 직접 설정) SSL 인증서 발급 자동화 용도로만 쓰이는 상태. **실제 트래픽을 새 클러스터로 전환하려면 Cloudflare에서 각 도메인의 A 레코드(root + wildcard)를 `34.64.94.80`으로 직접 변경해야 함** — 이 작업은 아직 진행되지 않았고, 실제 서비스 다운타임/전환 리스크가 있는 단계라 사용자 확인 후 진행 필요.

**실행 중 발견/해결한 이슈**:

- `cert-manager-dns01-key` 시크릿이 옛 프로젝트(`yango-495502`) 소속 서비스 계정 키였음 — 그대로 쓰면 Phase 6에서 구 프로젝트 삭제 시 인증서 갱신이 깨짐. 새 프로젝트에 `cert-manager-dns01@yango-501407` 서비스 계정을 새로 만들어 `roles/dns.admin` 부여 후 키 교체.
- DNS-01 챌린지가 계속 `403 Forbidden`으로 실패했던 최초 원인은 위 서비스 계정 문제였고, 그 다음 발견된 근본 원인이 Cloudflare 권위 DNS 문제였음. 사용자가 Cloudflare에서 `_acme-challenge` 서브도메인 NS 위임을 설정한 뒤 정상적으로 발급됨.

**검증 체크리스트:**

| 서비스 | 확인 방법 | 결과 |
|--------|---------|------|
| ArgoCD | 로그인 확인 | 미검증 (도메인 미전환) |
| Ojeomneo | 앱 정상 동작 | 클러스터 내부 기준 정상 |
| ReviewMaps | 앱 정상 동작 | 클러스터 내부 기준 정상 |
| Hotsao | 앱 정상 동작 | 클러스터 내부 기준 정상 |
| Yangobot | 앱 정상 동작 | 파드 Healthy |
| Grafana | 대시보드 확인 | 해당 없음 (모니터링 스택 비활성화 상태) |

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
| `gcp/terraform/environments/prod/main.tf` | 최초 부트스트랩을 위해 `external_secrets` 모듈을 일시 비활성화했다가 GKE 생성 후 재활성화 (2단계 커밋) |
| `gcp/terraform/modules/cloud-sql/main.tf` | `null_resource`가 `POSTGRES_HOST`도 함께 갱신하도록 수정 (기존엔 `POSTGRES_SERVER`만 갱신하는 버그) |
| `gcp/terraform/modules/gke/main.tf` | `spot_pool_medium`, `spot_pool_large`의 `node_count`에 `lifecycle.ignore_changes` 추가 (오토스케일러가 조정한 노드 수를 Terraform이 되돌리지 않도록) |

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
- 실제 도메인 권위 DNS는 Cloudflare이므로, Google Cloud DNS 존 생성만으로는 트래픽이 전혀 전환되지 않음 (SSL 인증서 자동 발급용 `_acme-challenge` 위임에만 사용됨)
- `argocd-rbac-policy` ExternalSecret의 `SecretSyncedError`는 이관과 무관한 기존 이슈로 남아있음 (미수정)

## 남은 작업 (다음 세션 참고용)

- [ ] Cloudflare에서 각 도메인 A레코드를 `34.64.94.80`으로 변경 (실제 트래픽 전환, 사용자 승인 필요)
- [ ] 전환 후 24시간 모니터링, 에러율/응답 확인
- [ ] Phase 6: 7일 안정화 후 `yango-495502` 최종 백업 및 리소스 정리
- [ ] `argocd-rbac-policy` ExternalSecret 설정 정리 (기존 이슈, 선택 사항)

## 최종 업데이트

- 작성일: 2026-02-17 (구 → yango-495502 이관 기준)
- 갱신일: 2026-07-04 (yango-495502 → yango-501407 이관 기준, Phase 0~4 완료 및 Phase 5 부분 완료)
- 이관 대상 프로젝트: `yango-501407`

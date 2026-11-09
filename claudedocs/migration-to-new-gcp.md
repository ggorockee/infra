# GCP 프로젝트 이관 가이드

## 이관 개요

| 항목 | 기존 | 신규 |
|------|------|------|
| Project ID | `yango-501407` | `yanggo-514212` |
| 소유 계정 | `woohalabs10@gmail.com` | `woohalabs11@gmail.com` |
| 조직 | 없음 | `woohalabs11-org` (신규 조직 — 보안 기본 정책 영향) |
| 결제 계정 | `019BE5-B9EFB8-C3E4D3` | `01B392-392E5A-9FEE6D` (계정별 상이) |
| TF State 버킷 | `yango-501407-tfstate` | `yanggo-514212-tfstate` |
| 신 Gateway IP | `34.64.94.80` | `34.22.107.0` |
| GKE 클러스터 | `woohalabs-prod-gke` (zonal `asia-northeast3-a`) | 동일 (zonal) |
| 리전 | `asia-northeast3` | `asia-northeast3` (동일) |

이 문서는 과거 이관 문서를 이번 이관(`yango-501407` → `yanggo-514212`) 기준으로 갱신한 버전입니다. 이전 이관들(`→ yango-495502`, `yango-495502 → yango-501407`)과 달리, 이번엔 **구/신 프로젝트 소유 계정이 다르고(woohalabs10 → woohalabs11) 신 프로젝트가 조직 산하**라 크로스 계정·조직 정책 이슈가 다수 발생했습니다. 또한 이번 이관은 **선택적 전환**입니다: `ggorockee.com`, `review-maps.com`, `woohalabs.com` 3개 도메인만 전환하고 `hotsao`는 내림(제외).

> ⚠️ 이번 이관에서 새로 발견된 함정들은 각 Phase의 "실행 중 발견된 이슈"와 하단 "이번 이관(yanggo-514212) 추가 발견사항"에 정리되어 있음. **gcp-migrator GUI 도구**(`tools/gcp-migrator`)에도 일부 반영됨.

## 이관 체크리스트

### Phase 0 - 새 프로젝트 사전 준비 (콘솔/gcloud)

- [x] 새 프로젝트에 결제 계정 연결 (`019BE5-B9EFB8-C3E4D3`)
- [x] 필수 API 활성화 (아래 목록)
- [x] Terraform 서비스 계정 생성 및 권한 부여 (`roles/owner`)
- [x] (신규 조직만) SA 키 생성 차단 org 정책 해제
- [x] GCS 버킷 생성 (Terraform state용, 버전관리 활성화)
- [x] 서비스 계정 키 다운로드 (스크래치패드에 보관, GitHub Secrets 등록 후 로컬 파일 삭제 예정)

**실행 중 발견된 이슈 (신규 조직 보안 기본값)**: 신규 GCP 조직 산하 프로젝트는 `constraints/iam.disableServiceAccountKeyCreation` 가 기본 강제되어 SA 키 생성이 `FAILED_PRECONDITION` 으로 막힘. org 관리자(`resourcemanager.organizationAdmin`)가 ① 본인에게 `roles/orgpolicy.policyAdmin` 부여 → ② `gcloud resource-manager org-policies disable-enforce iam.disableServiceAccountKeyCreation --project=[PROJECT]` 로 프로젝트 레벨 해제. 실효 정책이 `booleanPolicy: {}` 로 바뀐 뒤에도 **실제 키 생성 허용까지 최대 ~7분 전파 지연**이 있어, 바로 `keys create` 하면 여전히 실패할 수 있으므로 2~3분 뒤 재시도 필요. (이전 `yango-495502`/`yango-501407` 이관 때는 조직이 없어 미발생, `yanggo-514212` 이관에서 최초 발견.) 결제 계정도 소유 계정별로 다르므로(구 `019BE5-...` ≠ 신 `01B392-...`) **신 소유 계정으로 로그인한 상태에서** 조회·연결해야 함.

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
  - `GCP_PROJECT_ID` → `yanggo-514212`
  - `GCP_SA_KEY` → 새 서비스 계정 키 내용 (JSON)
- [x] feature 브랜치 PR → main 머지 (#1102 1차 부트스트랩, #1104 external_secrets 재활성화)
- [x] GitHub Actions `gcp-terraform-apply` 워크플로우 성공 확인
- [x] 신규 GKE 클러스터 접근 확인 (⚠️ 클러스터는 **zonal**이라 `--region`이 아닌 `--zone=asia-northeast3-a`, 클러스터명 `woohalabs-prod-gke`)

**실행 중 발견된 이슈 (external_secrets 2단계 부트스트랩)**: `external_secrets` 모듈의 `kubernetes_manifest`(ClusterSecretStore)는 GKE가 이미 떠 있어야 plan이 통과함. 그래서 1차 apply(#1102)는 모듈을 주석 처리해 GKE만 생성하고, 2차 apply(#1104)로 재활성화하는 2단계가 필요.

ESO CRD 순서 문제 상세 (이번에 정립된 절차): 2차 재활성화 전에 ESO CRD(`external-secrets v0.9.11`)를 **Helm 소유권 메타데이터와 함께 수동 선설치**해야 plan·apply가 충돌 없이 통과함. 구체적으로 `helm template external-secrets/external-secrets --version 0.9.11 --set installCRDs=true`에서 CRD만 추출해 `kubectl apply --server-side` 한 뒤, 모든 `*.external-secrets.io` CRD에 라벨 `app.kubernetes.io/managed-by=Helm` + 어노테이션 `meta.helm.sh/release-name=external-secrets`, `meta.helm.sh/release-namespace=external-secrets-system` 를 부착. ⚠️ **네임스페이스는 `external-secrets`가 아니라 `external-secrets-system`** 임 — release-namespace 어노테이션을 틀리면 apply가 `invalid ownership metadata ... must equal "external-secrets-system"` 로 실패함(이번에 실제 겪음, 어노테이션 수정 후 재apply로 해결). 2차 apply 성공 후 ESO 파드 3개 Running + `ClusterSecretStore gcpsm-secret-store` 가 `READY=True(Valid)` 면 정상.

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

**실행 중 발견된 이슈 (yanggo-514212 이관, 순서·계정 함정)**: 이 Phase는 문서상 Phase 1 뒤에 있지만, 실제로는 **Phase 1의 Cloud SQL apply보다 먼저** 수행해야 함. Cloud SQL 모듈(`modules/cloud-sql/main.tf`)이 `data.google_secret_manager_secret_version` 으로 `prod-ojeomneo-db-credentials`, `prod-reviewmaps-db-credentials` 를 **apply 시점에 읽기** 때문에, 시크릿이 없으면 apply가 `Error 404: Secret not found` 로 실패함. 또한 구/신 프로젝트 **소유 계정이 다르면**(구 `yango-501407`=woohalabs10, 신 `yanggo-514212`=woohalabs11) 단일 계정으로는 복제 불가 — 읽기는 구 소유 계정, 쓰기는 신 소유 계정으로 `--account` 를 분리해야 함. (참고: Service Networking Connection 생성이 `Error code 16 invalid auth` 로 간헐 실패하는데, apply 재실행하면 통과함 — 일시적 토큰 오류.)

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

**실제로 사용한 절차** (계획했던 Cloud SQL Auth Proxy + pg_dump/psql 대신, 네트워크 접근 불필요한 서버사이드 export/import 사용). ⚠️ 이번엔 **크로스 계정**이라 export는 구 소유 계정(woohalabs10), import는 신 소유 계정(woohalabs11)으로 `--account`를 분리해야 함:

1. 전송 버킷을 신 프로젝트에 생성하고, **구 인스턴스 SA**에 `storage.objectAdmin`(쓰기), **신 인스턴스 SA**에 `storage.objectViewer`(읽기)를 부여 (양쪽 SA 이메일은 `gcloud sql instances describe ... --format='value(serviceAccountEmailAddress)'`로 확인)
2. `gcloud sql export sql prod-woohalabs-cloudsql gs://[BUCKET]/[DB].sql --database=[DB] --project=yango-501407 --account=woohalabs10@gmail.com`
3. `gcloud sql import sql prod-woohalabs-cloudsql gs://[BUCKET]/[DB].sql --database=[DB] --project=yanggo-514212 --account=woohalabs11@gmail.com`
4. 정합성 검증: 신 인스턴스에서 다시 export하여 구 export와 **바이트 단위 일치** 확인 (이번에 ojeomneo/reviewmaps/hotsao 3개 모두 일치 확인)

**실행 중 발견된 이슈**:

- 이관 대상 DB가 계획에는 `ojeomneo`, `reviewmaps` 2개였으나, 실제로는 **`hotsao` DB가 하나 더 존재**했음 (Terraform 미관리, 수동 생성분). 위 절차와 동일하게 추가로 이관하고 `gcloud sql databases create hotsao`, `gcloud sql users create hotsao`로 신규 인스턴스에 사전 생성함.
- `gcp/terraform/modules/cloud-sql/main.tf`의 `null_resource.update_ojeomneo_secret` / `update_reviewmaps_secret`가 Secret Manager의 `POSTGRES_SERVER` 필드만 새 Private IP로 갱신하고, 앱이 실제로 사용하는 `POSTGRES_HOST` 필드는 갱신하지 않아서 이관 후에도 앱이 옛 프로젝트의 Cloud SQL Private IP로 연결을 시도하는 버그를 발견함 (ojeomneo, reviewmaps 둘 다 영향). PR #1098로 코드 수정, 이미 존재하는 시크릿은 수동으로 패치. `hotsao-app-secrets`의 `DB_HOST`도 동일한 문제라 같이 수동 패치함.

### Phase 4 - 워크로드 이관

- [x] 새 GKE 클러스터 kubeconfig 설정 (`--zone=asia-northeast3-a`)
- [x] ArgoCD **helm 설치** (`helm install argocd charts/helm/prod/argo-cd -n argocd --create-namespace`, 이번엔 사용자가 helm으로 진행) + Git 저장소 연결
- [x] ApplicationSets 적용 → 앱 자동 배포 (ojeomneo, reviewmaps, istio, cert-manager, gke-backendconfig, gke-storageclass, woohalabs-app-ads, yangobot — **hotsao 제외**)
- [x] Istio Ingress Gateway IP 확인 → `34.22.107.0`

**실행 중 발견/해결한 이슈**:

- `istio-ingressgateway` 파드가 istiod의 sidecar-injector webhook이 준비되기 전에 스케줄되어 `image: auto` 상태로 ImagePullBackOff 발생 (매 이관 반복되는 함정). 파드 삭제(`kubectl delete pod -n istio-system -l app=istio-ingressgateway`)로 재생성하여 정상 이미지(`proxyv2`)로 교체됨.
- `istio-gateway-config`의 `grafana-vs`, `prometheus-vs` VirtualService가 `monitoring` 네임스페이스를 참조 → 모니터링 스택 비활성화로 ns 없어 동기화 실패. `monitoring` 네임스페이스만 생성해서 해결.
- **hotsao 비활성화 — ApplicationSet glob 함정**: hotsao를 내리려고 `apps-hotsao-cfg.yaml`을 `configurations/prod/legacy/`로 옮겼으나, `infra-infrastructure-prod` ApplicationSet의 git files generator 경로 `charts/argocd/configurations/prod/*-cfg.yaml`이 **`legacy/` 하위까지 재귀 매칭**하여 여전히 Application이 생성됨(crash-loop). → 저장소의 비활성화 규칙인 **`.del` 접미사**(`apps-hotsao-cfg.yaml.del`)로 rename해야 glob에서 제외됨(#1105 → #1106). 이후 hotsao Application 수동 삭제 + 네임스페이스 정리로 완전히 내림. (hotsao-server 가 crash하던 직접 원인은 Terraform 미관리 시크릿 `hotsao-app-secrets`의 `DB_HOST`가 구 프로젝트 IP를 가리킨 것 — ojeomneo/reviewmaps는 `null_resource`가 자동 갱신하지만 hotsao는 수동 대상.)
- `argocd-rbac-policy` ExternalSecret `SecretSyncedError`는 이관 무관 기존 이슈로 그대로 둠.

### Phase 5 - DNS 전환 및 검증 — **완료**

- [x] 새 Istio Ingress Gateway 외부 IP 확인 (`34.22.107.0`) — ⚠️ `.0`으로 끝나지만 GCP 공인 LB IP로 정상 (GCP 포워딩 룰로 교차 확인)
- [x] Cloud DNS 존(`ggorockee-com`, `review-maps-com`, `woohalabs-com` 등)이 `yanggo-514212`에 존재, cert-manager DNS-01 solver가 `_acme-challenge` TXT 생성
- [x] HTTPS 인증서 발급 확인 (**ggorockee.com, review-maps.com, woohalabs.com 3개** 발급 완료 — hotsao 제외)
- [x] 각 앱 정상 동작 확인 (도메인 통한 실제 HTTPS: argocd.ggorockee.com 200, review-maps.com 200, woohalabs.com 301)
- [x] **DNS 레코드 실제 전환 (Cloudflare A레코드 → `34.22.107.0`)** — 사용자가 Cloudflare에서 3개 도메인 root+wildcard A레코드 변경 (hotsao.com은 미전환 = 제외)

**중요**: 각 도메인 권위 DNS는 **Cloudflare**(`isaac.ns.cloudflare.com`, `hope.ns.cloudflare.com`). Google Cloud DNS 존은 트래픽 라우팅에 관여하지 않고, `_acme-challenge.<domain>` NS 위임을 통해 SSL 인증서 발급에만 사용됨. 실제 전환은 Cloudflare A레코드 변경으로 완료.

**실행 중 발견/해결한 이슈 (이번 이관의 가장 큰 난관 — cert-manager DNS-01):**

1. **403 Forbidden (근본 원인)**: 이관한 `cert-manager-dns01-key` 시크릿이 **구 프로젝트 SA 키**(`cert-manager-dns01@yango-501407`)였음. 신 프로젝트 Cloud DNS에 권한이 없어 cert-manager가 TXT 생성 시 `GoogleCloud API call failed: 403 Forbidden`. 해결 절차: ① `cert-manager-dns01@yanggo-514212` SA에 `roles/dns.admin` 부여 → ② 새 키 발급 → ③ GCP Secret `cert-manager-dns01-key`(신 프로젝트)에 새 키로 버전 추가 → ④ ExternalSecret(`clouddns-dns01-solver-sa`) 강제 재동기화(관리 시크릿 삭제) → ⑤ cert-manager 재시작. 이 solver 시크릿은 ESO가 동기화하므로 GCP Secret만 바꾸면 됨.
2. **존 dnsName 오타**: `review-maps-com` 존의 dnsName이 `review.maps.com.`(오타, 정상은 `review-maps.com.`)이라 cert-manager가 매칭 존을 못 찾음. **존 dnsName은 생성 후 변경 불가** → 존을 삭제 후 올바른 dnsName으로 재생성. ⚠️ **재생성하면 네임서버가 바뀜**(ns-cloud-b → ns-cloud-d) → Cloudflare의 `_acme-challenge.review-maps.com` NS 위임도 새 네임서버로 다시 바꿔야 함(안 바꾸면 SOA 조회가 `SERVFAIL`).
3. **Cloudflare `_acme-challenge` NS 위임은 도메인별로 다름**: 각 도메인의 `_acme-challenge.<domain>` NS를 해당 Google Cloud DNS 존의 네임서버로 위임해야 함. 존마다 ns-cloud 세트가 다름(이번: ggorockee=ns-cloud-**e**, woohalabs=ns-cloud-**a**, review-maps=ns-cloud-**d**). 존 네임서버는 `gcloud dns managed-zones describe [ZONE] --format='value(nameServers)'`로 확인.
4. **멈춘 챌린지 강제 재시도**: 위임 수정 후에도 백오프로 재시도가 느리면, `kubectl delete order,certificaterequest -n istio-system [이름]`으로 order/CR을 삭제하면 cert-manager가 새 order로 즉시 재시도함.

**최종 검증 결과 (실제 HTTPS):** ggorockee.com 루트는 404/미라우팅(기존부터, argocd 서브도메인이 실서비스) · argocd.ggorockee.com 200 · review-maps.com 200 · woohalabs.com 301. 인증서 3개 모두 발급 완료.

### Phase 6 - 기존 프로젝트 정리 — **완료**

- [x] 신 클러스터 실트래픽 정상 확인 후 즉시 삭제 진행 (DNS 전환 당일)
- [x] 기존 Cloud SQL **최종 재백업** — DB export 시점(초기 이관) 이후 DNS 전환 전까지의 델타를 보존하기 위해, 삭제 직전 `ojeomneo`/`reviewmaps`/`hotsao` 3개 DB를 `gs://yanggo-514212-sqlmigrate/final-*.sql` 로 다시 export (ojeomneo/reviewmaps는 델타 없음, hotsao만 소폭 증가 — hotsao.com이 미전환 상태로 구에서 계속 쓰기 받은 탓)
- [x] 기존 프로젝트(`yango-501407`) 삭제 요청 (`gcloud projects delete yango-501407 --account=woohalabs10@gmail.com --quiet`) — `lifecycleState: DELETE_REQUESTED`, 30일 이내 `gcloud projects undelete yango-501407`로 복구 가능, 30일 후 영구 삭제. 리소스를 하나씩 영구 삭제하는 대신 프로젝트 삭제(복구 가능)를 선택.

> **hotsao.com 주의**: 이번 이관에서 hotsao는 제외했고 hotsao.com은 미전환(구 프로젝트 `34.64.94.80` 유지)이라, 구 프로젝트가 완전 삭제되면 hotsao.com도 함께 종료됨 (의도된 동작).

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
| `GCP_PROJECT_ID` | `yanggo-514212` 로 업데이트 |
| `GCP_SA_KEY` | 새 프로젝트 서비스 계정 키 JSON으로 업데이트 (`gh secret set GCP_SA_KEY < terraform-key.json --repo ggorockee/infra`) |

---

## 주의사항

- Cloud SQL `deletion_protection = true` 설정으로 실수 삭제 방지됨
- 데이터 이관 시 서비스 다운타임 발생 (DB migration 단계)
- Spot 노드 사용으로 이관 중 노드 회수 가능성 있음 (GKE 배포 시 주의)
- Workload Identity 바인딩은 Terraform apply 시 자동 설정됨 (`external-secrets-prod@`, `argocd-prod@` SA)
- `kubernetes/jobs/cloud-sql-restore/*/service-account.yaml`은 Terraform 미관리 리소스라 수동으로 새 프로젝트 SA를 만들고 어노테이션을 갱신해야 함
- 실제 도메인 권위 DNS는 Cloudflare이므로, Google Cloud DNS 존 생성만으로는 트래픽이 전혀 전환되지 않음 (SSL 인증서 자동 발급용 `_acme-challenge` 위임에만 사용됨)
- `argocd-rbac-policy` ExternalSecret의 `SecretSyncedError`는 이관과 무관한 기존 이슈로 남아있음 (미수정)

## 이번 이관(yanggo-514212) 추가 발견사항 요약

다음 이관에서 반복될 수 있는 함정들 (크로스 계정 + 신규 조직 환경 특유):

| 영역 | 함정 | 대응 |
|------|------|------|
| Phase 0 | 신규 조직은 `iam.disableServiceAccountKeyCreation` 강제 → SA 키 생성 불가 | orgpolicy.policyAdmin 자가부여 → `disable-enforce` → ~7분 전파 후 재시도 |
| Phase 0 | 결제 계정이 소유 계정별로 다름 | 신 소유 계정으로 로그인해 조회·연결 |
| Phase 2 | Cloud SQL apply가 DB 시크릿을 읽음 → 시크릿이 먼저 있어야 함 | Phase 2를 Phase 1 apply보다 먼저 수행 |
| Phase 2/3 | 구/신 소유 계정 다름 | 읽기/쓰기 `--account` 분리 |
| Phase 1 | ESO 네임스페이스는 `external-secrets-system` | CRD 소유권 어노테이션 release-namespace 정확히 일치 |
| Phase 4 | ApplicationSet glob `*-cfg.yaml`이 `legacy/` 재귀 매칭 | 비활성화는 `.del` 접미사로 |
| Phase 5 | 이관한 `cert-manager-dns01-key`가 구 프로젝트 SA 키 → 403 | 신 SA에 dns.admin + 새 키 + Secret 교체 + ESO 재동기화 |
| Phase 5 | 존 dnsName 오타는 재생성만 가능 → 네임서버 변경됨 | Cloudflare `_acme-challenge` NS 위임도 새 네임서버로 재설정 |

## 남은 작업 (다음 세션 참고용)

- [x] Cloudflare에서 3개 도메인(ggorockee/review-maps/woohalabs) A레코드를 `34.22.107.0`으로 변경 (2026-11-09 완료, 사용자가 직접 진행)
- [x] `yango-501407` 최종 재백업 및 프로젝트 삭제 요청 완료 (2026-11-09, DNS 전환 당일)
- [ ] 30일 undelete 창구 종료 전까지 필요시 `gcloud projects undelete yango-501407`로 복구 가능하다는 점 인지
- [ ] hotsao 완전 정리 여부 결정 (앱 제외됨, hotsao.com은 구 프로젝트 삭제와 함께 종료)
- [ ] `argocd-rbac-policy` ExternalSecret 설정 정리 (기존 이슈, 선택 사항)

## 최종 업데이트

- 작성일: 2026-02-17 (구 → yango-495502 이관 기준)
- 갱신일: 2026-07-04 (yango-495502 → yango-501407 이관 완료)
- 갱신일: 2026-11-09 (**yango-501407 → yanggo-514212 이관 완료** — Phase 0~6 전체 완료, 크로스 계정·신규 조직 환경)
- 이관 대상 프로젝트: `yanggo-514212`

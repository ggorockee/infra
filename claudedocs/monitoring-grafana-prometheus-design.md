# 모니터링 재구축 설계: Grafana + Prometheus 단일 스택

- 작성일: 2026-11-13
- 대상 클러스터: `woohalabs-prod-gke` (GCP 프로젝트 `yanggo-514212`)
- 브랜치: `feature/monitoring-chart-upgrade`
- Grafana 주소: https://monitoring.ggorockee.com

## 1. 목표

| 항목 | 내용 |
|------|------|
| 유지 | kube-prometheus-stack 93.2.2 (Prometheus Operator, Prometheus, Grafana, Alertmanager, kube-state-metrics, node-exporter) |
| 제거 | Loki, fluent-bit, otel-collector, SigNoz 관련 설정, 중복 차트 `monitoring/kube-prometheus-stack` |
| 배포 방식 | `argocd_yaml/`의 ApplicationSet → Application 생성 |
| 값 관리 | 차트 `values.yaml`은 upstream 원본 유지, 환경별 override는 `charts/argocd/applicationsets/valuefiles/prod/{폴더}/values.yaml` 하나로 일원화 |
| 리뷰맵 요구사항 | CronJob 성공/실패 확인, DB 적재 건수 확인, 실패 시 알림 |

## 2. 현재 상태 (2026-11-13 확인)

| 항목 | 상태 |
|------|------|
| monitoring 네임스페이스 | 존재하지만 리소스 없음 (이관 시 누락) |
| ApplicationSet `infra-monitoring-prod` | 클러스터에 존재, 대상 cfg 파일(`monitoring-prom-grafana-cfg.yaml`)이 없어 Application 0개 |
| ApplicationSet `infra-logging-prod` | 클러스터에 존재, 대상 cfg 파일 없음 → Application 0개 |
| Istio VirtualService | `grafana.ggorockee.com` → `kube-prometheus-stack-grafana:80`, `prom.ggorockee.com` → `kube-prometheus-stack-prometheus` 이미 정의됨 |
| Secret Manager | `prod-monitoring-smtp-credentials`, `prod-reviewmaps-db-credentials` 존재 |
| GKE Managed Prometheus (GMP) | 클러스터에 활성화됨 (중복 수집 경로) |
| 노드 | e2-highmem-2 × 2 (할당 가능 CPU 1930m, 메모리 약 13GiB/노드), 현재 사용률 CPU 6%, 메모리 23~28% |
| ArgoCD | v3.2.1 (multi-source Application 지원) |

## 3. 아키텍처

| 구성요소 | 역할 | 데이터 소스 |
|----------|------|-------------|
| kube-state-metrics | CronJob/Job 상태 메트릭 노출 | Kubernetes API |
| Prometheus | 메트릭 수집·저장(15일), 알림 규칙 평가 | ServiceMonitor 전체 네임스페이스 |
| Alertmanager | 알림 이메일 발송 | Prometheus 알림 |
| Grafana | 대시보드 | Prometheus(기본), Cloud SQL PostgreSQL(리뷰맵 DB 조회) |

리뷰맵 확인 흐름: CronJob 실행 → kube-state-metrics가 Job 성공/실패 노출 → Prometheus 규칙이 실패·미실행 감지 → Alertmanager 이메일. DB 적재 건수는 Grafana가 Cloud SQL을 직접 조회해 표시.

## 4. ArgoCD 구조

### 4.1 파일 배치

| 경로 | 역할 | 변경 |
|------|------|------|
| `argocd_yaml/prod-applicationsets-prom-grafana.yaml` | ApplicationSet `infra-monitoring-prod` | multi-source로 재작성 |
| `argocd_yaml/prod-applicationsets-logging.yaml` | ApplicationSet `infra-logging-prod` | 삭제 (클러스터에서도 삭제) |
| `charts/argocd/configurations/prod/monitoring-kube-prometheus-stack-cfg.yaml` | generator 입력 (앱 1개 = 파일 1개) | 신규 |
| `charts/argocd/applicationsets/valuefiles/prod/kube-prometheus-stack/values.yaml` | prod override 값 (유일한 override 파일) | 재작성 |
| `charts/helm/prod/kube-prometheus-stack/values-override.yaml` | 기존 override | 내용 이전 후 삭제 |

`monitoring-*-cfg.yaml` 패턴은 `infra-infrastructure-prod`에서 이미 exclude 되어 있어 중복 소유 충돌이 없습니다.

### 4.2 cfg 파일 필드

```json
{
  "env": "prod",
  "revision": "main",
  "repoURL": "https://github.com/ggorockee/infra.git",
  "chartName": "kube-prometheus-stack",
  "appName": "kube-prometheus-stack",
  "namespace": "monitoring",
  "valuesDir": "kube-prometheus-stack"
}
```

- `appName`은 반드시 `kube-prometheus-stack` (Helm 릴리스명 → 서비스명이 기존 VirtualService 대상과 일치해야 함)
- `valuesDir`로 override 폴더를 지정 → 다른 모니터링 앱 추가 시 cfg 파일만 추가

### 4.3 ApplicationSet 템플릿 (multi-source)

| source | 내용 |
|--------|------|
| source 1 (차트) | repo `{{repoURL}}`, path `charts/helm/{{env}}/{{chartName}}`, valueFiles: `values.yaml`, `$values/charts/argocd/applicationsets/valuefiles/{{env}}/{{valuesDir}}/values.yaml` |
| source 2 (값 참조) | repo `{{repoURL}}`, targetRevision `{{revision}}`, `ref: values` |

| 설정 | 값 | 이유 |
|------|-----|------|
| syncOptions | `CreateNamespace=true`, `ServerSideApply=true` | Prometheus Operator CRD가 커서 client-side apply annotation 한도 초과 |
| ignoreDifferences | Alertmanager/Prometheus `/status` | Operator가 status를 갱신 |
| automated | `prune: true`, `selfHeal: true` | 기존 정책 유지 |

ApplicationSet 자체는 GitOps 대상이 아니므로 머지 후 `kubectl apply -f argocd_yaml/prod-applicationsets-prom-grafana.yaml`로 수동 반영합니다.

## 5. values 설계 (valuefiles/prod/kube-prometheus-stack/values.yaml)

### 5.1 기존 values-override.yaml에서 이전/정리

| 항목 | 처리 |
|------|------|
| 최상위 `externalSecret`, `clusterSecretStore` | 삭제 (참조하는 템플릿 없음) |
| `grafana.externalSecret` (SMTP + OAuth, `prod-monitoring-smtp-credentials`) | 유지 |
| Grafana Google OAuth, 관리자 이메일 role 매핑 | 유지 |
| `grafana.additionalDataSources` Loki | 삭제 |
| `grafana.additionalDataSources` PostgreSQL (리뷰맵) | 신규 추가 (6.2) |
| `kube-state-metrics.enabled`, `prometheus-node-exporter.enabled` | 새 키 `kubeStateMetrics.enabled`, `nodeExporter.enabled`로 교체 |
| `defaultRules.rules.k8s` | 삭제 (93.x에서 세분화된 키로 변경, 기본값 true) |
| 스토리지 클래스 | `gcp-standard-rwo-retain` 유지 |
| Alertmanager 이메일 라우팅 | 유지 |

### 5.2 리소스 및 스토리지

| 컴포넌트 | requests | limits | PVC |
|----------|----------|--------|-----|
| Prometheus | 200m / 1Gi | 1000m / 3Gi | 20Gi (retention 15d, retentionSize 18GB) |
| Grafana | 100m / 256Mi | 500m / 512Mi | 5Gi |
| Alertmanager | 50m / 64Mi | 200m / 256Mi | 2Gi |
| kube-state-metrics | 50m / 64Mi | 200m / 256Mi | 없음 |
| node-exporter (노드당) | 20m / 32Mi | 100m / 64Mi | 없음 |

기존 Prometheus requests(500m/2Gi)는 노드 2대 클러스터에서 CPU 예약 비중이 커서 축소합니다. 운영 후 실제 사용량을 보고 조정합니다.

### 5.3 컨트롤 플레인 대상 비활성화

GKE는 컨트롤 플레인 컴포넌트에 접근할 수 없으므로 수집 실패 알림을 막기 위해 끕니다.

| 키 | 값 |
|----|-----|
| `kubeControllerManager.enabled` | false |
| `kubeScheduler.enabled` | false |
| `kubeEtcd.enabled` | false |
| `kubeProxy.enabled` | false |

## 6. 리뷰맵 CronJob 모니터링

### 6.1 대상 CronJob

| CronJob | 스케줄 (KST) | 정상 기준 |
|---------|--------------|-----------|
| `reviewmaps-go-cron-inflexer` | 매일 00:05 | 26시간 내 성공 1회 이상 |
| `reviewmaps-go-cron-reviewnote` | 매일 02:00 | 26시간 내 성공 1회 이상 |
| `reviewmaps-go-cleanup` | 매일 05:00 | 26시간 내 성공 1회 이상 |

### 6.2 Grafana PostgreSQL 데이터소스

| 항목 | 내용 |
|------|------|
| 접속 정보 | ExternalSecret으로 `prod-reviewmaps-db-credentials` → monitoring 네임스페이스 Secret 생성, 환경변수로 Grafana에 주입 |
| 계정 | 읽기 전용 계정 `grafana_ro` 신규 생성 권장 (`campaign` 테이블 SELECT 권한만). 생성 전까지는 기존 계정 사용 가능하나 쓰기 권한이 있어 비권장 |
| 데이터소스 이름 | `ReviewMaps-DB` |

### 6.3 대시보드 `reviewmaps-cronjob-dashboard.json`

| 패널 | 데이터 소스 | 쿼리 개요 |
|------|-------------|-----------|
| CronJob별 마지막 성공 경과 시간 | Prometheus | `time() - kube_cronjob_status_last_successful_time{namespace="reviewmaps"}` |
| 최근 Job 성공/실패 | Prometheus | `kube_job_status_succeeded`, `kube_job_status_failed` (namespace=reviewmaps) |
| Job 실행 시간 | Prometheus | `kube_job_status_completion_time - kube_job_status_start_time` |
| 다음 실행 예정 | Prometheus | `kube_cronjob_next_schedule_time` |
| 오늘 플랫폼별 적재 건수 | PostgreSQL | `campaign` 테이블에서 `created_at`이 오늘(KST)인 행을 `platform`별 count |
| 최근 7일 일별 적재 추이 | PostgreSQL | `created_at` 일 단위 group by, `platform`별 시계열 |
| 마감 지난 잔존 캠페인 (cleanup 검증) | PostgreSQL | `apply_deadline < 오늘` 행 count, 0이 정상 |

`created_at` 기준 집계가 가능한 이유: go-scraper가 DELETE 후 INSERT 방식으로 저장하여 매 실행마다 `created_at`이 갱신됩니다.

### 6.4 알림 규칙 (`additionalPrometheusRulesMap`)

| 알림 | 조건 | 심각도 |
|------|------|--------|
| ReviewmapsCronJobNotSucceeded | 마지막 성공 후 26시간 초과 | critical |
| ReviewmapsJobFailed | Job 최종 실패 1분 지속 (CronJob명 표시) | critical (초기 warning에서 상향) |
| ReviewmapsJobSucceeded | Job 성공 (Job당 메일 1통, 해제 메일 없음) | info |
| ReviewmapsJobRunningTooLong | 활성 Job 실행 시간 2시간 초과 | warning |

DB 적재 0건 알림은 Prometheus로 SQL을 평가할 수 없어 미구현. 대신 수집 서버의 0건 수집·수집량 급감 알림(6.6)으로 대체합니다. 전체 알림 목록은 `.claude/CLAUDE.md` "운영 현황 > 알림" 참고.

### 6.5 이 스택으로 해결되지 않는 것

| 한계 | 영향 | 보완 |
|------|------|------|
| GKE 워크로드 로그 비활성 + Job TTL 1시간 | 실패 원인 로그가 1시간 후 사라짐 | `failedJobsHistoryLimit: 3`이라 실패 Job은 TTL 전까지 남음. 필요 시 `ttlSecondsAfterFinished` 연장 |
| 키워드별 수집 건수 | ~~알 수 없음 (otel-collector 제거)~~ | 6.6 Pushgateway로 해결 |

### 6.6 수집 서버 모니터링 (Pushgateway, 2026-11-13 추가)

go-scraper는 CronJob에서 키워드마다 프로세스를 띄워 수 초~수 분 만에 끝나므로 Prometheus가 pull로 수집할 수 없습니다. 실행 결과를 Pushgateway에 push하고 Prometheus가 Pushgateway를 수집합니다.

| 구성 | 내용 |
|------|------|
| Pushgateway | `charts/helm/prod/prometheus-pushgateway` (3.11.2), ApplicationSet `infra-monitoring-prod`, PVC 1Gi로 재시작 시 보존, ServiceMonitor honorLabels |
| push 주소 | go-scraper ConfigMap `PUSHGATEWAY_URL=http://prometheus-pushgateway.monitoring.svc.cluster.local:9091` |
| push 시점 | 키워드 시작 시 running=1, 종료 시 결과 + running=0 (성공·실패 모두) |
| grouping | `job=reviewmaps_scraper`, `scraper`, `keyword` (`@base64` 인코딩) |
| 코드 | reviewmaps `go-scraper/internal/runstats` |

| 메트릭 | 내용 |
|--------|------|
| `reviewmaps_scraper_running` | 1=실행 중, 0=종료 |
| `reviewmaps_scraper_run_started_timestamp_seconds` | 키워드 시작 시각 |
| `reviewmaps_scraper_last_run_success` | 마지막 실행 1=성공, 0=실패 |
| `reviewmaps_scraper_last_success_timestamp_seconds` | 마지막 성공 시각 (실패 시 갱신 안 함) |
| `reviewmaps_scraper_last_run_duration_seconds` | 소요 시간 |
| `reviewmaps_scraper_last_run_items{stage}` | scraped / parsed / saved / updated / new / deleted |
| `reviewmaps_scraper_last_run_enrich{type}` | total / cache_hit / api_call / geocode / skipped / error |
| `reviewmaps_scraper_last_run_alerts_created` | 생성된 키워드 알림 수 |
| `reviewmaps_scraper_last_run_server_api_error` | 키워드 알림 서버 API 실패 여부 |

| 확인된 함정 | 대응 |
|-------------|------|
| client_golang push가 공백을 `+`로 보내 Pushgateway에 `서울+강남`으로 저장 | grouping 값을 `@base64`로 직접 인코딩 |
| 실패 push가 이전 성공 시각을 덮어쓸 위험 | POST(같은 이름 메트릭만 교체) + 실패 시 last_success 미전송 |
| 키워드를 설정에서 빼면 그룹이 남아 KeywordStale 계속 발생 | Pushgateway에서 해당 그룹 DELETE |

대시보드 "ReviewMaps 수집 서버"(`reviewmaps-scraper`)와 알림 6종(ReviewmapsScraper*)은 `.claude/CLAUDE.md` "운영 현황" 참고.

## 7. 제거 대상

| 대상 | 위치 | 비고 |
|------|------|------|
| Loki 차트 | `charts/helm/prod/loki/` | 미배포 |
| fluent-bit 차트 | `charts/helm/prod/fluent-bit/` | 미배포 |
| otel-collector 차트 | `charts/helm/prod/otel-collector/` | 미배포 (이번 브랜치의 업그레이드 커밋은 무효화) |
| 중복 차트 | `charts/helm/prod/monitoring/` | 미사용 |
| valuefiles | `valuefiles/prod/loki`, `otel-collector`, `fluent-bit` | |
| ApplicationSet | `argocd_yaml/prod-applicationsets-logging.yaml` + 클러스터의 `infra-logging-prod` | 생성된 앱 없음 |
| Loki 연동 | `templates/loki-datasource.yaml`, 대시보드 `all-logs`, `loki-official`, `*-logs*` (5개) | |
| OTel 환경변수 | reviewmaps values의 `OTEL_EXPORTER_OTLP_ENDPOINT`, `SIGNOZ_ENDPOINT` | 값이 없으면 go-scraper telemetry가 no-op으로 동작함을 코드에서 확인. server는 적용 전 확인 필요 |
| 루트 잔여 파일 | `signoz-reviewmaps-dashboard.json` | |
| GMP | GKE 클러스터 설정 | `gcloud container clusters update` 필요 → 개발자 승인 대상, 스택 안정화 후 진행 |

## 8. 확정 사항 (2026-11-13)

| 항목 | 결정 |
|------|------|
| 외부 노출 | Grafana만 `monitoring.ggorockee.com`으로 노출 (와일드카드 인증서·DNS 기존 적용). `prom.ggorockee.com` VirtualService 비활성화 |
| Grafana 관리자 | 사용자명 `woohaen88`, 비밀번호는 Secret Manager `prod-monitoring-smtp-credentials.password` |
| Grafana DB 조회 계정 | 별도 읽기 전용 계정 미생성, 기존 리뷰맵 계정 사용 (Grafana Explore는 Editor 이상만 가능, Admin은 지정 이메일 3개뿐) |
| GMP | 비활성화 (스택 정상화 확인 후 승인 받아 실행) |
| Alertmanager 이메일 | 유지. 설정은 ESO 템플릿으로 생성한 Secret `alertmanager-custom-config` 사용 |

### 구현 중 확인된 사항

| 항목 | 내용 |
|------|------|
| cleanup 동작 | 물리 삭제가 아니라 soft delete(`deleted_at` 설정). 대시보드 쿼리는 모두 `deleted_at IS NULL` 조건 사용 |
| 기존 Alertmanager 설정 버그 | 이전 values-override의 `$SMTP_HOST` 등 환경변수 치환은 Alertmanager가 지원하지 않아 동작하지 않았음 → ESO 템플릿 방식으로 교체 |
| 기존 HTTP 대시보드 | `reviewmaps-dashboard.json`은 서버 `/metrics` 미구현(500)으로 데이터 없음. 유지하되 서버 메트릭 구현 시 사용 |
| Google OAuth | 기존 클라이언트(`937024223104-...`)가 삭제된 상태(`deleted_client`)로 확인되어 `yanggo-514212`에 새 웹 클라이언트 생성. Grafana·ArgoCD Dex 공용, 리디렉션 URI 2개 등록 |

## 9. 작업 체크리스트

### Phase 1: 정리
- [x] 제거 대상 디렉터리·파일 삭제 (7장)
- [x] reviewmaps values에서 OTel 환경변수 제거 (server 영향 확인 후)
- [x] 클러스터의 ApplicationSet `infra-logging-prod` 삭제

### Phase 2: 배포 구조
- [x] `argocd_yaml/prod-applicationsets-prom-grafana.yaml` multi-source로 재작성
- [x] `monitoring-kube-prometheus-stack-cfg.yaml` 추가
- [x] `valuefiles/prod/kube-prometheus-stack/values.yaml` 재작성 (5장)
- [x] 차트 내 `values-override.yaml` 삭제
- [x] `helm template`으로 두 values 파일 합성 결과 검증

### Phase 3: 리뷰맵 모니터링
- [x] Grafana PostgreSQL 데이터소스 + ExternalSecret
- [x] `reviewmaps-cronjob-dashboard.json` 추가
- [x] 알림 규칙 3종 추가

### Phase 4: 반영 및 검증
- [x] Google OAuth 클라이언트 신규 생성 및 Secret Manager 반영 (v3, v1은 롤백용 보존)
- [x] PR 생성 → 머지
- [x] ApplicationSet 수동 apply
- [x] Application Synced/Healthy 확인
- [x] Grafana 로그인(관리자 계정), 데이터소스 2종 연결, 대시보드 로드 확인
- [x] 알림 테스트 (테스트 알림 이메일 1건 발송, 실패 0건)
- [x] (승인 후) GMP 비활성화

### 배포 결과 (2026-11-13)

| 항목 | 결과 |
|------|------|
| PR | #1118 (스택 구성), #1119 (ExternalSecret OutOfSync 수정) |
| ArgoCD `kube-prometheus-stack` | Synced / Healthy (리소스 117개) |
| Prometheus 수집 대상 | 9종 전부 up |
| 리뷰맵 CronJob 메트릭 | 3종 수집, 알림 규칙 3종 정상 로드 |
| 외부 접근 | `monitoring.ggorockee.com` 정상, `prom.ggorockee.com` 404 |
| GMP | 비활성화 완료, Terraform 코드에 반영 |
| Google OAuth | 새 클라이언트 반영, Grafana·ArgoCD 로그인 화면 정상 연결 |

### 후속 조치 (2026-11-13)

| 항목 | 내용 |
|------|------|
| OAuth 클라이언트 | `yanggo-514212` 웹 클라이언트 신규, 리디렉션 URI: `monitoring.ggorockee.com/login/generic_oauth`, `argocd.ggorockee.com/api/dex/callback` |
| Secret Manager | `prod-monitoring-smtp-credentials`, `prod-argocd-dex-credentials` v3 (키 형식: `google.clientId` 평면 키 유지) |
| 로컬 보관 | `.secrets/oauth-client_yanggo-514212_monitoring-argocd.json` (gitignore, PR #1121) |
| ArgoCD RBAC | `argocd-rbac-policy` ExternalSecret 비활성화, `policy.csv`에 관리자 3명 직접 지정 (PR #1122, helm rev 2) |
| 동의 화면 | Testing 상태 → Audience의 Test users에 등록된 계정만 로그인 가능 |
| 수집 서버 모니터링 | Pushgateway + go-scraper push (infra #1131, reviewmaps #277, #279), 대시보드·알림 (infra #1132, #1135, #1136) |
| 발견·수정한 운영 버그 | 서버 /metrics 500 (reviewmaps #275), AutoMigrate 위험 DDL (#276), cleanup 기준일 UTC 오류로 만료 캠페인 하루 더 노출 (#278), 알림 메일 스팸 분류 (infra #1130), 응답 지연 알림 오탐 (#1138) |
| 대시보드 가독성 | 범위표 접기, 짧은 이름, 글자 크기 고정, hh:mm:ss (infra #1141, #1142). 작성 규칙은 `.claude/CLAUDE.md` "Grafana 대시보드" |

## 10. 클러스터 전체 모니터링 (2026-11-13 추가)

원칙: "모니터링할 수 없는 것은 관리할 수 없다." 클러스터에서 돌아가는 모든 서비스에 대해 (1) 살아 있는가 (2) 정상 범위 안에서 동작하는가 (3) 벗어나면 메일이 오는가를 보장한다.

### 10.1 서비스별 감시 방법

앱에 /metrics가 없는 서비스도 Istio gateway 지표(외부 요청)와 blackbox 접속 검사로 감시한다.

| 서비스 | 살아 있는가 | 동작 지표 |
|--------|------------|-----------|
| 리뷰맵 API (reviewmaps-server) | blackbox `reviewmaps-api`, 앱 /metrics `up` | 앱 지표(요청·5xx·P95), Istio |
| 리뷰맵 웹/관리자 | blackbox `reviewmaps-web(-www)`, `reviewmaps-admin` | Istio (요청·5xx·P95) |
| 리뷰맵 CronJob·수집 서버 | kube-state-metrics, Pushgateway | 기존 reviewmaps.* 규칙 |
| 오점너 API (ojeomneo-server) | blackbox `ojeomneo-api`, 앱 /ojeomneo/metrics `up` | 앱 지표(DB 풀 포함), Istio |
| 오점너 웹/관리자 | blackbox `ojeomneo-web`, `ojeomneo-admin` | Istio |
| 오점너 Redis | blackbox PING `ojeomneo-redis` | redis-exporter (메모리, 거부 연결) |
| yangobot / yangobot Redis | blackbox `yangobot` (/healthz), PING `yangobot-redis` | Istio, 컨테이너 자원 |
| woohalabs app-ads.txt | blackbox `woohalabs-app-ads(-www)` | Istio |
| ArgoCD | blackbox `argocd`, PING `argocd-redis` | argocd_app_info, sync 결과 (PodMonitor) |
| Grafana | blackbox `grafana` | 기본 ServiceMonitor |
| Istio | Deployment 가용성 | istiod xDS 거부, gateway 요청 지표 |
| cert-manager | Deployment 가용성 | Certificate Ready·갱신 시각, 실제 인증서 만료일(blackbox) |
| External Secrets | Deployment 가용성 | ExternalSecret Ready 상태 |
| Cloud SQL (reviewmaps, ojeomneo DB) | postgres-exporter `pg_up` | 연결 수, DB 크기, deadlock, 긴 트랜잭션, 캐시 적중률 |
| 노드·클러스터 | kube-state-metrics 노드 Ready | node-exporter CPU/메모리/디스크, requests 예약률 |
| 모든 워크로드 (kube-system 포함) | Deployment/StatefulSet 가용 Pod 0개 | 재시작, OOMKilled, 시작 실패, 메모리 limit 대비, PVC |

### 10.2 추가 구성요소

| 구성요소 | 위치 | 비고 |
|----------|------|------|
| blackbox exporter 11.21.3 | 차트 `charts/helm/prod/prometheus-blackbox-exporter`, override `valuefiles/prod/prometheus-blackbox-exporter/values.yaml` | 외부 URL 12개 + 내부 Redis 3개, 30~60초 간격. 검사 대상 추가는 override `serviceMonitor.targets` |
| postgres-exporter 8.2.5 | 차트 `charts/helm/prod/prometheus-postgres-exporter`, override `valuefiles/prod/prometheus-postgres-exporter/values.yaml` | 접속 계정은 Secret `grafana-reviewmaps-db` 재사용 |
| 추가 ServiceMonitor | kube-prometheus-stack override `prometheus.additionalServiceMonitors` | istiod, ojeomneo-server, ojeomneo-redis |
| 추가 PodMonitor | kube-prometheus-stack override `prometheus.additionalPodMonitors` | ArgoCD 전체, External Secrets, Istio ingress gateway (서비스 요청 지표만 keep) |
| cert-manager ServiceMonitor | `charts/helm/prod/cert-manager/values.yaml` `prometheus.servicemonitor.enabled` | |
| 대시보드 | `dashboards/cluster-overview-dashboard.json` (uid `cluster-overview`) | 범위표 = 아래 10.4 |

### 10.3 메일 등급

| 제목 | severity | 의미 | 반복 발송 | 해제 메일 |
|------|----------|------|-----------|-----------|
| [CRITICAL] | critical | 서비스 중단 또는 중단 직전, 즉시 조치 | 2시간 | 있음 |
| [ERROR] | error | 기능 실패, 조치 필요 | 6시간 | 있음 |
| [WARN] | warning | 정상 범위 벗어남, 추이 확인 | 12시간 | 있음 |
| [INFO] | info | 참고용 (재시작 1회, 배포 완료, Job 성공) | 24시간 | 없음 |

- 초기 단계라 INFO까지 전부 발송한다. 줄일 때는 `files/alertmanager.yaml.tmpl`에서 info 라우트의 receiver를 `"null"`로 바꾸고, 그다음 warning 라우트를 바꾼다.
- 같은 알림의 상위 등급이 발생 중이면 하위 등급은 억제한다 (critical → error/warning/info, error → warning/info). 접속 불가 시 응답 지연, 재시작 반복 시 재시작 1회, Deployment 중단 시 replicas 불일치도 억제한다.
- 기존 리뷰맵 규칙: Job 실패·26시간 미성공·키워드 실패·5xx는 error([ERROR] 유지), 서버 다운은 critical([CRITICAL])로 변경. 기존 warning은 제목만 [ALERT] → [WARN].
- 기본 규칙 중 NodeMemoryHighUtilization, NodeCPUHighUsage는 커스텀 규칙으로 대체해 비활성화.

### 10.4 지표별 정상 범위와 알림 기준

| 영역 | 지표 | 🟢 정상 | 알림 (조건 → 등급) |
|------|------|---------|-------------------|
| 노드 | Ready 노드 수 | 2대 | 2대 미만 5분 → CRITICAL |
| 노드 | CPU 사용률 | 5~50% (평소 약 10%) | 80% 초과 15분 → WARN |
| 노드 | 메모리 사용률 | 20~60% (평소 약 30%) | 80% 초과 15분 → WARN, 95% 초과 5분 → CRITICAL |
| 노드 | 데이터 디스크 (/mnt/stateful_partition) | 75% 미만 (평소 55~72%, 컨테이너 이미지) | 80% 초과 30분 → WARN |
| 용량 | CPU requests 예약률 | 75% 미만 (현재 약 64%) | 85% 초과 15분 → WARN |
| 용량 | 메모리 requests 예약률 | 75% 미만 (현재 약 22%) | 85% 초과 15분 → WARN |
| 용량 | 배치 불가 Pod | 0 | 5분 → ERROR |
| 워크로드 | 가용 Pod 0개 Deployment/StatefulSet | 0 | 3분 → CRITICAL |
| 워크로드 | 컨테이너 재시작 | 0회 | 10분 내 1회 → INFO, 1시간 3회 → WARN |
| 워크로드 | OOMKilled | 0회 | 발생 → ERROR |
| 워크로드 | ImagePull/CreateContainerConfig 실패 | 0 | 5분 → ERROR |
| 워크로드 | 메모리 limit 대비 사용 (kube-system·gke-managed 제외) | 70% 미만 | 90% 초과 15분 → WARN |
| 스토리지 | PVC 사용률 | 70% 미만 (Prometheus 최대 약 75%) | 85% 초과 30분 → WARN |
| 접속 | 외부 URL / Redis PING | 항상 성공 | 3분 실패 → CRITICAL |
| 접속 | 접속 시간 | 0.5초 미만 (평소 0.03~0.5초) | 2초 초과 10분 → WARN |
| 접속 | HTTPS 인증서 남은 일수 | 30~90일 | 21일 미만 → WARN, 7일 미만 → CRITICAL |
| 트래픽 | 서비스 5xx 비율 | 1% 미만 | 5% 초과 + 10분 5건 이상 → ERROR |
| 트래픽 | 서비스 P95 (앱 네임스페이스) | 300ms 미만 | 1초 초과 15분 → WARN |
| 트래픽 | 요청 수 (어제 같은 시각 대비) | 50~200% | 30% 미만 30분 → WARN, 5배 초과 15분 → WARN |
| 트래픽 | 4xx 비율 | 알림 없음 (봇 요청이 많아 대시보드 참고만) | - |
| ArgoCD | 앱 Sync | 전부 Synced | OutOfSync 30분 → WARN |
| ArgoCD | 앱 Health | 전부 Healthy | Degraded/Missing 15분 → ERROR |
| ArgoCD | sync 결과 | 성공 | 실패 → ERROR, 성공 → INFO (배포 완료 메일) |
| 인증서 | cert-manager Certificate | 전부 Ready | Not Ready 15분 → ERROR, 갱신 예정일 하루 경과 → WARN |
| Secret | ExternalSecret | 전부 SecretSynced | Ready=False 10분 → ERROR |
| Istio | xDS 설정 거부 | 0건 | 발생 → WARN |
| DNS | CoreDNS SERVFAIL 비율 | 1% 미만 | 5% 초과 10분 → WARN |
| DB | Cloud SQL 접속 (pg_up) | 성공 | 실패 2분 → CRITICAL, exporter 지표 없음 10분 → ERROR |
| DB | 연결 수 (max 100) | 50 미만 | 80% 초과 10분 → WARN |
| DB | deadlock | 0건 | 발생 → WARN |
| DB | 가장 긴 트랜잭션 | 1분 미만 | 10분 초과 5분 → WARN |
| DB | 캐시 적중률 | 99% 이상 | 90% 미만 30분 → INFO |
| DB | 데이터 크기 (디스크 20GB) | 10GB 미만 | 14GB 초과 → WARN |
| Redis | 거부 연결 / maxmemory 대비 | 0건 / 70% 미만 | 거부 발생 → WARN, 90% 초과 15분 → WARN |
| 오점너 | API 서버 /metrics 수집 | 성공 | 5분 실패 → CRITICAL |
| 오점너 | DB 커넥션 풀 사용률 | 50% 미만 | 90% 초과 10분 → WARN |
| 모니터링 | blackbox 지표 | 수집됨 | 10분 없음 → ERROR |

### 10.5 이번 범위에서 다루지 못한 것

| 항목 | 이유 / 필요한 작업 |
|------|-------------------|
| Cloud SQL CPU·메모리·디스크 실사용량 | GCP Cloud Monitoring 지표 → Grafana에 Google Cloud Monitoring 데이터소스 + 서비스 계정 IAM(monitoring.viewer) 필요. gcloud 쓰기 작업이라 승인 후 진행 |
| 알림 시스템 자체 장애 감지 | Prometheus/Alertmanager가 죽으면 메일이 안 옴. Watchdog 알림을 외부 dead man's switch(예: healthchecks.io)로 보내야 감지 가능 |
| ojeomneo 외 앱 내부 지표 | 리뷰맵 웹·관리자, 오점너 웹·관리자, yangobot은 /metrics가 없어 외부 요청 지표와 접속 검사로만 감시 |
| yangobot·argocd Redis 상세 지표 | exporter sidecar를 붙이면 Redis Pod가 재시작되고 yangobot Redis는 persistence가 꺼져 있어 데이터가 사라짐 → PING 검사로 대체 |

### 10.6 작업 체크리스트

- [x] 수집 대상 조사 (현재 수집 중 / 누락 서비스, 앱별 /metrics 여부, 헬스체크 경로)
- [x] 기준값 측정 (노드 CPU 약 10%, 메모리 약 30%, CPU 예약률 약 64%, 서비스별 응답 코드 분포)
- [x] blackbox exporter, postgres-exporter 차트 추가
- [x] ArgoCD·ESO·Istio·ojeomneo·cert-manager 수집 설정
- [x] 클러스터 전체 알림 규칙 추가, 기존 리뷰맵 규칙 등급 조정
- [x] Alertmanager 등급별 라우팅 (INFO까지 발송), 메일 제목 [CRITICAL]/[ERROR]/[WARN]/[INFO]
- [x] 클러스터 전체 현황 대시보드
- [x] 머지 후 ArgoCD Synced/Healthy 확인 (#1146, 전체 앱 Synced/Healthy)
- [x] 새 수집 대상 전부 up 확인 (53개 up, 접속 검사 15개 성공)
- [x] 배포 직후 발생하는 알림 확인 및 오탐 조정 (#1147 Istio 필터·CPU 계산·디스크 범위·GKE 관리 컴포넌트 제외, #1148 비율 0 표시, exporter CPU limit 상향)
- [x] 테스트 메일 4등급 발송 (Alertmanager 발송 실패 0건, 수신은 메일함에서 확인)
- [x] 대시보드 화면 확인 (Playwright 캡처)
- [ ] 오점너 Redis exporter CPU 쓰로틀링 (limit 50m): ojeomneo 차트 `redis.metrics.resources` 상향 필요, 변경 시 Redis Pod 재시작되므로 개발자 확인 후 진행

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
| ReviewmapsJobFailed | `kube_job_status_failed{namespace="reviewmaps"} > 0` 이 10분 지속 | warning |
| ReviewmapsJobRunningTooLong | 활성 Job 실행 시간 2시간 초과 | warning |

DB 적재 0건 알림은 Prometheus로 SQL을 평가할 수 없으므로 2단계에서 Grafana Alerting으로 추가합니다.

### 6.5 이 스택으로 해결되지 않는 것

| 한계 | 영향 | 보완 |
|------|------|------|
| GKE 워크로드 로그 비활성 + Job TTL 1시간 | 실패 원인 로그가 1시간 후 사라짐 | `failedJobsHistoryLimit: 3`이라 실패 Job은 TTL 전까지 남음. 필요 시 `ttlSecondsAfterFinished` 연장 |
| 키워드별 수집 건수 | 알 수 없음 (otel-collector 제거) | DB 일별 집계로 대체 |

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


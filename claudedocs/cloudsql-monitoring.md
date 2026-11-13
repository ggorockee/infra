# Cloud SQL 인스턴스 자원 모니터링 (Cloud Monitoring → Prometheus)

작성일: 2026-11-13 / 대상: `prod-woohalabs-cloudsql` (프로젝트 `yanggo-514212`)

## 1. 목적

postgres-exporter는 DB **내부** 상태(접속 가능 여부, 연결 수, DB 크기, deadlock, 캐시 적중률)만 볼 수 있다. Cloud SQL은 관리형이라 인스턴스의 CPU·메모리·디스크 실사용량은 GCP(Cloud Monitoring)만 알고 있다. 이 값을 클러스터 안 Prometheus로 가져와서 기존 알림(메일)·대시보드와 같은 체계로 감시한다.

| 질문 | 어디서 보나 |
|------|------------|
| DB에 접속되는가, 연결이 몇 개인가, 쿼리가 막혔는가 | postgres-exporter (기존) |
| 인스턴스 CPU·메모리가 부족한가, 디스크가 차고 있는가, 자동 확장되었는가 | **stackdriver-exporter (이번 작업)** |

## 2. 대상 인스턴스

| 항목 | 값 |
|------|-----|
| 인스턴스 | `prod-woohalabs-cloudsql` (POSTGRES_15) |
| 등급 | db-g1-small (공유 코어, 메모리 1.7GB) |
| 디스크 | 20GB (실제 20.96GB), 자동 확장 켜짐 |
| max_connections | 100 |
| 사설 IP | 172.29.0.3 |
| DB | reviewmaps, ojeomneo (hotsao DB도 있으나 사용하지 않음, 아래 9장) |

## 3. 아키텍처

| 단계 | 구성요소 | 설명 |
|------|---------|------|
| 1 | Cloud SQL | 60초마다 지표를 Cloud Monitoring에 기록 (GCP 기본, 추가 비용 없음) |
| 2 | prometheus-stackdriver-exporter (monitoring 네임스페이스) | 2분마다 Cloud Monitoring API에서 최근 5분 값을 읽어 `/metrics`로 노출 |
| 3 | Prometheus (kube-prometheus-stack) | ServiceMonitor로 수집, 알림 규칙 `database.cloudsql` 평가 |
| 4 | Alertmanager | 기존과 같은 메일 (woohaen88@gmail.com, [CRITICAL]/[ERROR]/[WARN]/[INFO]) |
| 5 | Grafana | 대시보드 "클러스터 전체 현황" 데이터베이스 행 "Cloud SQL 인스턴스 자원" |

Grafana에 Cloud Monitoring 데이터소스를 직접 붙이는 방법은 쓰지 않았다. 화면에서는 보이지만 Prometheus 알림 규칙에서 쓸 수 없어서 알림을 Grafana Alerting으로 따로 만들어야 하고, 메일 형식·등급·억제 규칙이 두 군데로 나뉘기 때문이다.

## 4. 권한 (Workload Identity, 키 파일 없음)

| 항목 | 값 | 관리 위치 |
|------|-----|-----------|
| GCP 서비스 계정 (GSA) | `monitoring-reader-prod@yanggo-514212.iam.gserviceaccount.com` | Terraform `gcp/terraform/modules/monitoring` |
| 프로젝트 권한 | `roles/monitoring.viewer` (지표 조회만, 쓰기·알림 정책 변경 불가) | Terraform |
| Workload Identity 바인딩 | `roles/iam.workloadIdentityUser` → `yanggo-514212.svc.id.goog[monitoring/prometheus-stackdriver-exporter]` | Terraform |
| Kubernetes 서비스 계정 (KSA) | `monitoring/prometheus-stackdriver-exporter`, 어노테이션 `iam.gke.io/gcp-service-account` = GSA | Helm (ArgoCD) override `serviceAccount` |
| 클러스터 설정 | Workload Pool `yanggo-514212.svc.id.goog`, 노드 메타데이터 `GKE_METADATA` (기존) | Terraform `modules/gke` |

- 같은 패턴을 External Secrets Operator(`external-secrets-prod` GSA)가 이미 쓰고 있다.
- Terraform은 로컬에서 plan/apply 하지 않는다. PR을 올리면 GitHub Actions가 plan을 실행하고, main에 머지하면 apply를 실행한다.
- KSA 이름 = Helm 릴리스명(`appName`)이다. 바꾸면 Terraform 변수 `kubernetes_service_account`도 같이 바꿔야 한다.

## 5. 수집 지표

Prometheus 지표 이름은 `stackdriver_cloudsql_database_cloudsql_googleapis_com_database_` 뒤에 아래 이름이 붙는다. 라벨 `database_id` = `yanggo-514212:prod-woohalabs-cloudsql`.

| Cloud Monitoring 지표 | Prometheus 접미사 | 의미 |
|----------------------|------------------|------|
| database/cpu/utilization | `cpu_utilization` | CPU 사용률 (0~1, 공유 코어는 1을 넘을 수 있음) |
| database/memory/utilization | `memory_utilization` | 메모리 사용률 (0~1) |
| database/memory/quota | `memory_quota` | 메모리 총량 (바이트) |
| database/disk/utilization | `disk_utilization` | 디스크 사용률 (0~1, WAL·임시 파일 포함) |
| database/disk/bytes_used | `disk_bytes_used` | 디스크 사용량 (바이트) |
| database/disk/quota | `disk_quota` | 디스크 크기 (바이트, 자동 확장 시 증가) |
| database/disk/read_ops_count, write_ops_count | `disk_read_ops_count`, `disk_write_ops_count` | 디스크 읽기·쓰기 횟수 |
| database/postgresql/transaction_id_utilization | `postgresql_transaction_id_utilization` | 트랜잭션 ID 소진율 (wraparound 위험) |
| database/up | `up` | 인스턴스 가동 여부 |
| database/uptime (prefix `up`에 함께 일치) | `uptime` | 가동 시간 |
| database/disk/bytes_used_by_data_type (prefix `disk/bytes_used`에 함께 일치) | `disk_bytes_used_by_data_type` | 데이터 종류별 디스크 사용량 (data, wal, tmp 등 6개 시계열) |

prefix는 앞부분 일치라서 `up`은 `uptime`, `disk/bytes_used`는 `disk/bytes_used_by_data_type`까지 함께 가져온다. 수집 지표를 늘리려면 override `stackdriver.metrics.prefixes`에 추가한다. 늘린 만큼 API 비용(반환 시계열 수)도 늘어난다.

## 6. 정상 범위와 알림

기준선은 2026-11-13 직전 24시간 Cloud Monitoring 값(시간별 최대)이다.

| 지표 | 기준선 | 🟢 정상 | 알림 (조건 → 등급) |
|------|--------|---------|-------------------|
| CPU 사용률 | 11~48% (수집 시간대에 높음) | 50% 미만 | 80% 초과 15분 → WARN (CloudSQLCPUHigh) |
| 메모리 사용률 | 51~55% | 65% 미만 | 80% 초과 15분 → WARN (CloudSQLMemoryHigh), 95% 초과 5분 → CRITICAL (CloudSQLMemoryCritical) |
| 디스크 사용률 | 3.6% (0.75GB / 20.96GB) | 50% 미만 | 80% 초과 30분 → WARN (CloudSQLDiskHigh) |
| 디스크 크기 | 20.96GB 고정 | 변화 없음 | 1시간 전보다 커짐 → INFO (CloudSQLDiskAutoResized) |
| 트랜잭션 ID 소진율 | 0.003% | 10% 미만 | 50% 초과 1시간 → WARN (CloudSQLTransactionIDWraparound) |
| 지표 수집 | - | 2분마다 수집 | 20분간 없음 → ERROR (CloudSQLMetricsMissing) |
| DB 접속 | - | 항상 성공 | postgres-exporter `PostgresDown` (CRITICAL, 기존) |

- 메모리 95%(CRITICAL)가 발생 중이면 같은 인스턴스의 80%(WARN) 메일은 억제한다.
- 기존 `PostgresStorageHigh`(DB 데이터 크기 14GB 초과)는 실제 디스크 사용률 규칙으로 대체하면서 삭제했다. DB별 크기는 대시보드 "DB 크기" 패널에서 참고용으로 계속 본다.
- 지표는 Cloud Monitoring 기록 지연 + 2분 수집 간격 때문에 실제보다 2~5분 늦다. 즉시성이 필요한 "접속 불가"는 postgres-exporter(30초)가 맡는다.

## 7. 비용

| 항목 | 내용 |
|------|------|
| 과금 기준 | Cloud Monitoring 읽기 API, 2025-10-02부터 **반환 시계열 수** 기준. 월 100만 개 무료, 초과 시 100만 개당 $0.50 |
| 실측 사용량 | 수집 1회당 시계열 17개 (2026-11-13 확인) × 2분 간격(월 21,600회) ≈ **월 약 37만 개** |
| 예상 비용 | $0 (무료 범위 안) |
| 서비스 계정·IAM | 무료 |
| exporter Pod | requests CPU 10m, 메모리 32Mi (노드 예약률 영향 거의 없음) |
| 주의 | Cloud SQL 인스턴스를 늘리거나 prefixes를 추가하면 비례해서 증가. 월 100만 개를 넘기려면 지금의 약 2.7배가 필요 (인스턴스 3개 이상이면 수집 간격 5분으로 조정 검토) |

참고: Google Cloud Observability 가격 (https://cloud.google.com/products/observability/pricing), 무료 사용량 한도 (https://docs.cloud.google.com/free/docs/free-cloud-features).

## 8. AWS 대응 개념

| GCP (현재) | AWS 대응 | 차이 |
|-----------|---------|------|
| Cloud SQL for PostgreSQL | RDS for PostgreSQL | 거의 동일한 관리형 DB |
| Cloud Monitoring `cloudsql.googleapis.com/database/*` | CloudWatch `AWS/RDS` 네임스페이스 (CPUUtilization, FreeableMemory, FreeStorageSpace) | RDS는 사용률 대신 "남은 양"(Freeable/Free) 위주 |
| prometheus-stackdriver-exporter | prometheus-cloudwatch-exporter 또는 YACE | 둘 다 클라우드 모니터링 API를 읽어 Prometheus로 변환 |
| Workload Identity (KSA ↔ GSA) | IRSA 또는 EKS Pod Identity (ServiceAccount ↔ IAM Role) | 키 파일 없이 Pod에 클라우드 권한 부여 |
| `roles/monitoring.viewer` | `cloudwatch:GetMetricData`, `cloudwatch:ListMetrics` 정책 | |
| 읽기 API 과금: 반환 시계열 수 | GetMetricData 과금: 요청한 지표 수 (1,000개당 $0.01) | |

클라우드 중립 관점: 수집 경로(exporter → Prometheus → Alertmanager)와 알림 규칙 구조는 그대로 두고 exporter와 권한 연결만 바꾸면 AWS로 옮길 수 있다.

## 9. 운영 메모 · 문제 해결

| 증상 | 확인 |
|------|------|
| CloudSQLMetricsMissing 발생 | `kubectl -n monitoring logs deploy/prometheus-stackdriver-exporter` — `PermissionDenied`면 GSA 권한/Workload Identity 바인딩, `could not find default credentials`면 KSA 어노테이션 확인 |
| Workload Identity 동작 확인 | `kubectl -n monitoring get sa prometheus-stackdriver-exporter -o yaml` 어노테이션, `gcloud iam service-accounts get-iam-policy monitoring-reader-prod@yanggo-514212.iam.gserviceaccount.com` |
| 값이 GCP 콘솔과 다름 | 2~5분 지연은 정상. 콘솔은 1분 단위, exporter는 최근 5분 중 마지막 값 |
| 비용 확인 | GCP 콘솔 결제 → Cloud Monitoring → "Monitoring API Read" SKU |
| hotsao DB 연결 | `hotsao` DB에 연결 1~2개가 열려 있으나 사용하지 않는 DB로 확인 대상 아님 (2026-11-13 개발자 확인). 알림 규칙은 reviewmaps·ojeomneo만 대상 |

## 10. 작업 체크리스트

- [x] 방식 결정: Grafana 데이터소스 대신 stackdriver-exporter (알림 체계 일원화)
- [x] 기준선 조회 (Cloud Monitoring API, 직전 24시간)
- [x] 비용 확인 (반환 시계열 기준 과금, 무료 범위)
- [x] Terraform `modules/monitoring` 작성, prod 연결, `terraform validate` 통과
- [x] stackdriver-exporter 차트 추가 (5.2.2), override·cfg 작성, 렌더링 확인
- [x] 알림 규칙 `database.cloudsql` 7개, 억제 규칙, PostgresStorageHigh 대체
- [x] 대시보드 "Cloud SQL 인스턴스 자원" 패널, 범위표
- [x] TERRAFORM_RESOURCES.md, CLAUDE.md 갱신
- [x] PR Terraform plan 결과 확인 (#1150, Plan: 3 to add, 0 to change, 0 to destroy)
- [x] 머지 후 Terraform apply 성공 확인 (Apply complete! Resources: 3 added)
- [x] exporter 수집 확인 (지표 이름·값이 기준선과 일치)
- [x] CloudSQLMetricsMissing 해소 확인
- [x] 실제 반환 시계열 수로 비용 재확인 (수집 1회 17개, 월 약 37만 개, 무료 범위)
- [x] 대시보드 화면 확인 (Playwright 캡처)

## 11. 배포 검증 결과 (2026-11-13)

| 항목 | 결과 |
|------|------|
| Terraform | PR #1150 plan 3개 추가 → 머지 후 apply 3개 추가 (10:04:36 UTC) |
| GSA | `monitoring-reader-prod` 생성, IAM 정책 멤버 `yanggo-514212.svc.id.goog[monitoring/prometheus-stackdriver-exporter]` |
| Workload Identity 전파 | apply 전후 첫 2회 수집은 권한 오류(바인딩 없음) → apply 약 1분 30초 후부터 성공. 새로 만들 때는 이 정도 지연이 정상 |
| ArgoCD | prometheus-stackdriver-exporter, kube-prometheus-stack 모두 Synced/Healthy |
| 수집 값 | CPU 10.2%, 메모리 50.6% (1.82GB 중), 디스크 3.57% (0.75GB / 20.96GB), 트랜잭션 ID 0.0035%, up 1 → 기준선과 일치 |
| Prometheus | 수집 대상 up (수집 시간 약 0.23초), CloudSQLMetricsMissing 해소, Cloud SQL 알림 발생 없음 |
| 대시보드 | "Cloud SQL 인스턴스 자원" CPU 11% / 메모리 51% / 디스크 4% 표시, 추이 차트 정상 |

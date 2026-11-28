# Observability 개선 작업 요약

> 2026-11-28: 아래의 Systems Overview·Database Performance 대시보드는 삭제됐습니다 (패널 대부분이 빈칸·오류, `claudedocs/monitoring-audit-2026-11-28.md`). 이 문서는 당시 기록입니다.

**날짜**: 2025-12-20
**목적**: ReviewMaps와 Ojeomneo 애플리케이션의 Observability 가시성 최대화
**범위**: 데이터베이스 메트릭, Grafana 대시보드, Alert Rules

---

## 1. 작업 개요

기존 APM/OTEL 설정을 기반으로 다음 3가지 영역에서 Observability를 개선했습니다:

1. **데이터베이스 메트릭 구현** - GORM 플러그인 기반 자동 메트릭 수집
2. **Grafana 대시보드 추가** - 통합 Overview 및 DB Performance 대시보드
3. **Alert Rules 설정** - 14개의 포괄적인 알림 규칙

---

## 2. 데이터베이스 메트릭 구현

### 2.1 ReviewMaps

**파일**: `internal/database/metrics.go` (신규)

**메트릭 (7개)**:
- `reviewmaps_db_query_duration_seconds` (Histogram) - 쿼리 실행 시간
- `reviewmaps_db_query_total` (Counter) - 쿼리 실행 횟수
- `reviewmaps_db_errors_total` (Counter) - 데이터베이스 에러
- `reviewmaps_db_slow_queries_total` (Counter) - 슬로우 쿼리 (>1초)
- `reviewmaps_db_connection_pool_size` (Gauge) - 커넥션 풀 최대 크기
- `reviewmaps_db_connection_pool_idle` (Gauge) - 유휴 커넥션 수
- `reviewmaps_db_connection_pool_in_use` (Gauge) - 사용 중 커넥션 수

**레이블**:
- `operation`: SELECT, INSERT, UPDATE, DELETE
- `table`: 테이블 이름
- `status`: success, error
- `error_type`: 에러 타입

**구현 패턴**:
- GORM v2 Plugin 시스템 활용
- Before/After 콜백으로 자동 메트릭 수집
- 백그라운드 goroutine으로 커넥션 풀 통계 수집 (30초 간격)

**설정**:
- MaxOpenConns: 25
- MaxIdleConns: 5
- ConnMaxLifetime: 300초

### 2.2 Ojeomneo

**파일**: `internal/module/db_metrics.go` (신규)

메트릭 패턴은 ReviewMaps와 동일하며, 메트릭 이름 prefix만 `ojeomneo_`로 변경:
- `ojeomneo_db_query_duration_seconds`
- `ojeomneo_db_query_total`
- `ojeomneo_db_errors_total`
- `ojeomneo_db_slow_queries_total`
- `ojeomneo_db_connection_pool_size`
- `ojeomneo_db_connection_pool_idle`
- `ojeomneo_db_connection_pool_in_use`

**통합 방식**: fx.Lifecycle OnStart 훅에서 플러그인 등록 및 백그라운드 collector 시작

---

## 3. Grafana 대시보드

### 3.1 Systems Overview Dashboard

**파일**: `charts/helm/prod/kube-prometheus-stack/dashboards/systems-overview-dashboard.json`

**목적**: ReviewMaps와 Ojeomneo의 전체 시스템 상태를 한눈에 파악

**패널 (10개)**:

**Row 1: Service Health**
- Overall Request Rate (Time Series) - 전체 RPS
- ReviewMaps Error Rate (Gauge) - 에러율 %
- Ojeomneo Error Rate (Gauge) - 에러율 %

**Row 2: Latency Comparison**
- ReviewMaps P95 Latency (Gauge)
- ReviewMaps P99 Latency (Gauge)
- Ojeomneo P95 Latency (Gauge)
- Ojeomneo P99 Latency (Gauge)

**Row 3: Database Performance**
- Database Query Rate (Time Series) - operation별 쿼리율
- Database Query Duration (Time Series) - P50/P95/P99

**Row 4: Cache & Connection Pool**
- Ojeomneo Cache Hit Rate (Gauge)
- Database Connection Pool Usage (Time Series) - in_use + idle

**특징**:
- 두 애플리케이션 비교 가능
- 실시간 성능 모니터링
- Critical 메트릭 시각화

### 3.2 Database Performance Dashboard

**파일**: `charts/helm/prod/kube-prometheus-stack/dashboards/database-performance-dashboard.json`

**목적**: 데이터베이스 성능 상세 분석

**패널 (8개)**:

**Row 1: Query Performance**
- Query Rate by Operation (Time Series) - SELECT/INSERT/UPDATE/DELETE별 쿼리율
- Query Rate by Table (Time Series) - 테이블별 쿼리율

**Row 2: Query Latency**
- Query Duration P50 (Time Series)
- Query Duration P95 (Time Series)
- Query Duration P99 (Time Series)

**Row 3: Connection Pool**
- ReviewMaps Connection Pool (Gauge) - in_use with thresholds
- Ojeomneo Connection Pool (Gauge) - in_use with thresholds

**Row 4: Database Errors**
- Database Errors by Type (Time Series) - 에러 타입별 분류

**Template Variables**:
- `app`: reviewmaps, ojeomneo 선택 가능
- `operation`: SELECT, INSERT, UPDATE, DELETE 필터링
- `table`: 테이블 필터링

**특징**:
- Percentile 분석 (P50, P95, P99)
- 슬로우 쿼리 추적
- 커넥션 풀 상태 모니터링 (Threshold: 15=yellow, 20=red)

---

## 4. Alert Rules

**파일**: `charts/helm/prod/kube-prometheus-stack/values-override.yaml`

**총 14개 Alert Rule** (각 앱당 7개)

### 4.1 HTTP Performance Alerts (4개)

**High Error Rate (Critical)**
- 조건: 5xx 에러율 5% 초과, 5분 지속
- 쿼리: `(sum(rate({app}_http_requests_total{status=~"5.."}[5m])) / sum(rate({app}_http_requests_total[5m]))) * 100 > 5`
- 알림: Critical severity, email-critical receiver

**High Latency (Warning)**
- 조건: P95 레이턴시 1초 초과, 5분 지속
- 쿼리: `histogram_quantile(0.95, sum by (le) (rate({app}_http_request_duration_seconds_bucket[5m]))) > 1`
- 알림: Warning severity, email-notifications receiver

### 4.2 Database Performance Alerts (6개)

**Slow Queries (Warning)**
- 조건: 초당 1개 이상 슬로우 쿼리 발생, 5분 지속
- 쿼리: `sum(rate({app}_db_slow_queries_total[5m])) > 1`
- 알림: Warning severity

**Connection Pool Exhaustion (Critical)**
- 조건: 커넥션 풀 사용량 20개 초과 (80%), 5분 지속
- 쿼리: `{app}_db_connection_pool_in_use > 20`
- 알림: Critical severity

**High DB Error Rate (Critical)**
- 조건: 초당 5개 이상 DB 에러, 5분 지속
- 쿼리: `sum(rate({app}_db_errors_total[5m])) > 5`
- 알림: Critical severity

### 4.3 Service Availability Alerts (4개)

**Service Down (Critical)**
- 조건: 2분간 HTTP 요청 없음
- 쿼리: `sum(rate({app}_http_requests_total[2m])) == 0`
- 알림: Critical severity

**Pod Restarting (Warning)**
- 조건: 15분간 Pod 재시작 발생
- 쿼리: `rate(kube_pod_container_status_restarts_total{namespace="{app}"}[15m]) > 0`
- 알림: Warning severity

### 4.4 Alert 라우팅

**Global SMTP 설정**:
- SMTP Host/Port: GCP Secret Manager (`prod-monitoring-smtp-credentials`)
- From Email: `$EMAIL_FROM`
- TLS 필수

**Receiver 설정**:

1. **email-notifications** (Warning)
   - 대상: `$ADMIN_EMAILS`
   - 반복 간격: 12시간
   - 템플릿: 일반 HTML 템플릿

2. **email-critical** (Critical)
   - 대상: `$ADMIN_EMAILS`
   - 반복 간격: 4시간
   - 템플릿: 빨간색 강조 HTML 템플릿 (🚨 아이콘)

**Route 설정**:
- severity=critical → email-critical receiver
- severity=warning → email-notifications receiver
- Group by: alertname, cluster, service
- Group wait: 10s
- Group interval: 10s

---

## 5. Git 커밋 내역

### 5.1 ReviewMaps Repository

**브랜치**: `feature/add-database-metrics`

**커밋 메시지**:
```
feat(database): Prometheus 데이터베이스 메트릭 수집 추가

GORM Plugin 기반 데이터베이스 메트릭 수집 구현:
- 7개 메트릭: 쿼리 duration, count, errors, slow queries, connection pool
- 자동 메트릭 수집: GORM Before/After 콜백
- 백그라운드 수집: Connection pool 통계 (30초 간격)
- 커넥션 풀 설정: MaxOpenConns=25, MaxIdleConns=5
```

**변경 파일**:
- `internal/database/metrics.go` (신규)
- `internal/database/database.go` (수정)
- `cmd/api/main.go` (수정)

### 5.2 Ojeomneo Repository

**브랜치**: `feature/add-database-metrics`

**커밋 메시지**:
```
feat(database): Prometheus 데이터베이스 메트릭 수집 추가

GORM Plugin 기반 데이터베이스 메트릭 수집 구현:
- 7개 메트릭: 쿼리 duration, count, errors, slow queries, connection pool
- 자동 메트릭 수집: GORM Before/After 콜백
- 백그라운드 수집: Connection pool 통계 (30초 간격)
- fx.Lifecycle 통합: OnStart 훅에서 플러그인 등록
- 커넥션 풀 설정: MaxOpenConns=25, MaxIdleConns=5
```

**변경 파일**:
- `internal/module/db_metrics.go` (신규)
- `internal/module/database.go` (수정)

### 5.3 Infra Repository

**브랜치**: `feature/add-observability-dashboards`

**커밋 1**: Grafana 대시보드 추가
```
feat(monitoring): Observability 향상을 위한 Grafana 대시보드 추가

2개의 Grafana 대시보드 추가:
- Systems Overview Dashboard: ReviewMaps + Ojeomneo 통합 모니터링 뷰
- Database Performance Dashboard: 데이터베이스 성능 상세 분석

주요 기능:
- 실시간 성능 메트릭 시각화
- P50/P95/P99 Percentile 분석
- Connection Pool 상태 모니터링
- 애플리케이션 간 비교 분석
```

**커밋 2**: Alert Rules 추가
```
feat(monitoring): Alert Rules 추가 - 서비스 모니터링 알림 설정

14개의 포괄적인 Alert Rule 추가:
- HTTP Performance (4개): High Error Rate, High Latency
- Database Performance (6개): Slow Queries, Connection Pool, DB Errors
- Service Availability (4개): Service Down, Pod Restarting

알림 라우팅:
- Critical 알림: email-critical receiver (4시간 간격)
- Warning 알림: email-notifications receiver (12시간 간격)

SMTP 이메일 알림:
- GCP Secret Manager SMTP 인증
- HTML 템플릿 상세 알림
```

**변경 파일**:
- `dashboards/systems-overview-dashboard.json` (신규)
- `dashboards/database-performance-dashboard.json` (신규)
- `values-override.yaml` (수정)

---

## 6. 배포 가이드

### 6.1 ReviewMaps/Ojeomneo 배포

**순서**:
1. PR 생성 및 코드 리뷰
2. main 브랜치 병합 (Squash and Merge)
3. 애플리케이션 재배포 (새 메트릭 활성화)
4. ServiceMonitor 자동 스크래핑 확인
5. Prometheus targets 확인: `http://prom.ggorockee.com/targets`

**검증 명령어**:
```bash
# Prometheus에서 메트릭 확인
curl -s "http://prom.ggorockee.com/api/v1/query?query=reviewmaps_db_query_total" | jq .
curl -s "http://prom.ggorockee.com/api/v1/query?query=ojeomneo_db_query_total" | jq .

# 커넥션 풀 메트릭 확인
curl -s "http://prom.ggorockee.com/api/v1/query?query=reviewmaps_db_connection_pool_in_use" | jq .
curl -s "http://prom.ggorockee.com/api/v1/query?query=ojeomneo_db_connection_pool_in_use" | jq .
```

### 6.2 Grafana 대시보드 배포

**순서**:
1. PR 생성 및 리뷰
2. main 브랜치 병합
3. ArgoCD 자동 배포 확인
4. Grafana에서 대시보드 확인: `https://grafana.ggorockee.com`

**ConfigMap 확인**:
```bash
kubectl get configmap -n monitoring | grep dashboard
kubectl describe configmap systems-overview-dashboard -n monitoring
kubectl describe configmap database-performance-dashboard -n monitoring
```

**Sidecar 로그 확인**:
```bash
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana -c grafana-sc-dashboard
```

### 6.3 Alert Rules 배포

**순서**:
1. PR 생성 및 리뷰
2. main 브랜치 병합
3. Helm 차트 업그레이드
4. PrometheusRule 리소스 생성 확인
5. Alertmanager 설정 확인

**검증 명령어**:
```bash
# PrometheusRule 확인
kubectl get prometheusrule -n monitoring
kubectl describe prometheusrule kube-prometheus-stack-custom-application-alerts -n monitoring

# Alertmanager 설정 확인
kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring -o yaml

# Alert 상태 확인
curl -s "http://prom.ggorockee.com/api/v1/rules" | jq '.data.groups[] | select(.name | contains("alerts"))'

# Alertmanager 상태 확인
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# 브라우저: http://localhost:9093
```

**테스트 Alert 발생**:
```bash
# 의도적으로 에러 발생시켜 Alert 테스트
# (실제 배포 전 staging 환경에서 테스트 권장)
```

---

## 7. 모니터링 체크리스트

### 7.1 메트릭 수집 확인
- [ ] ReviewMaps 메트릭이 Prometheus에 정상 수집되는가?
- [ ] Ojeomneo 메트릭이 Prometheus에 정상 수집되는가?
- [ ] 데이터베이스 쿼리 메트릭이 operation별로 분류되는가?
- [ ] 커넥션 풀 메트릭이 30초마다 업데이트되는가?
- [ ] 슬로우 쿼리가 정상적으로 카운트되는가?

### 7.2 대시보드 확인
- [ ] Systems Overview Dashboard가 Grafana에 표시되는가?
- [ ] Database Performance Dashboard가 Grafana에 표시되는가?
- [ ] 모든 패널이 데이터를 정상적으로 표시하는가?
- [ ] Template variables가 정상 작동하는가?
- [ ] Gauge 임계값이 올바르게 설정되었는가?

### 7.3 Alert 확인
- [ ] 14개 Alert Rule이 모두 로드되었는가?
- [ ] Alertmanager가 SMTP 설정을 정상 로드했는가?
- [ ] GCP Secret Manager에서 SMTP 인증 정보를 읽어오는가?
- [ ] Critical/Warning severity 라우팅이 올바른가?
- [ ] 이메일 템플릿이 정상적으로 렌더링되는가?

### 7.4 통합 테스트
- [ ] 실제 에러 발생 시 Alert가 트리거되는가?
- [ ] 이메일 알림이 정상 전송되는가?
- [ ] 대시보드에서 Alert 상태를 확인할 수 있는가?
- [ ] Alert 해소 시 resolve 이메일이 전송되는가?

---

## 8. 향후 개선 사항

### 8.1 추가 메트릭
- Cache 성능 메트릭 (ReviewMaps에도 추가)
- 외부 API 호출 메트릭 (latency, error rate)
- 비즈니스 메트릭 (사용자 행동, 트랜잭션)

### 8.2 대시보드 확장
- Business Metrics Dashboard
- Error Analysis Dashboard
- User Journey Dashboard

### 8.3 Alert 개선
- Adaptive threshold (통계 기반 동적 임계값)
- Runbook 문서 작성 및 링크 추가
- PagerDuty/Slack 통합

### 8.4 SLO/SLI 정의
- Service Level Objectives 정의
- Error Budget 계산
- SLO 기반 Alert 설정

---

## 9. 참고 자료

**Prometheus 메트릭 네이밍**:
- 메트릭 이름: `{app}_{component}_{metric_name}_{unit}`
- 레이블: operation, table, status, error_type

**Grafana 대시보드 패턴**:
- Time Series: 시계열 데이터 시각화
- Gauge: 현재 상태 및 임계값
- Template Variables: 동적 필터링

**Alert Rule 작성**:
- expr: PromQL 쿼리
- for: 지속 시간 조건
- labels: severity, service, category
- annotations: summary, description, runbook_url

**참고 문서**:
- Prometheus Best Practices: https://prometheus.io/docs/practices/naming/
- Grafana Dashboard Best Practices: https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/
- Alertmanager Configuration: https://prometheus.io/docs/alerting/latest/configuration/

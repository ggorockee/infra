# Kubernetes 클러스터 Observability 엔터프라이즈급 개선 계획

**작성일**: 2025-12-22
**대상 환경**: GKE Production Cluster
**목표**: 1인 개발자가 구현 가능한 엔터프라이즈급 Observability 시스템 구축

---

## 1. 현재 모니터링 스택 분석

### 1.1 배포된 컴포넌트

| 컴포넌트 | 버전/상태 | 리소스 사용량 | 역할 |
|---------|----------|-------------|------|
| Prometheus | 활성 | 531Mi / 90m CPU | 메트릭 수집 및 저장 |
| Grafana | 활성 | 278Mi | 시각화 및 대시보드 |
| Alertmanager | 활성 | 33Mi | 알림 라우팅 및 관리 |
| OpenTelemetry Collector | v0.91.0 | 35Mi / 100m CPU | OTLP 수신 및 처리 |
| kube-state-metrics | 활성 | - | Kubernetes 상태 메트릭 |
| prometheus-node-exporter | 활성 | - | 노드 레벨 메트릭 |

### 1.2 현재 모니터링 범위

**메트릭 수집 대상 (ServiceMonitor: 16개)**
- ArgoCD 컴포넌트 (7개): application-controller, server, repo-server, applicationset, notifications, dex, redis
- 애플리케이션 (4개): ojeomneo-server, ojeomneo-redis, reviewmaps-admin, reviewmaps-redis
- 인프라 (5개): cert-manager, OpenTelemetry Collector, kube-state-metrics, node-exporter, Prometheus 자체

**알림 규칙 (PrometheusRule: 37개)**
- 기본 규칙 활성화: Alertmanager, etcd, kubelet, kube-proxy, node, network, storage 등
- ArgoCD 전용: Redis HA, Application Controller 규칙
- 애플리케이션 전용: ojeomneo-redis, reviewmaps-redis

### 1.3 데이터 흐름 아키텍처

```
[애플리케이션]
   ↓ (OTLP HTTP/gRPC 4318/4317)
[OpenTelemetry Collector]
   ↓ (Prometheus Exporter :8889)
[Prometheus] ← (ServiceMonitor 스크레이핑)
   ↓
[Grafana] (시각화)
[Alertmanager] (알림)
```

### 1.4 현재 설정의 강점

- **표준 스택**: Prometheus Operator 기반 안정적 구성
- **GitOps 연동**: ArgoCD로 선언적 관리
- **OTLP 준비**: OpenTelemetry Collector 통한 표준 프로토콜 지원
- **메트릭 커버리지**: 인프라부터 애플리케이션까지 광범위한 수집

### 1.5 현재 설정의 약점

- **Logs 부재**: 로그 수집 및 중앙화 시스템 없음
- **Traces 미활용**: OTLP Traces는 수신하나 로깅만 하고 저장/분석 안 함
- **SLI/SLO 미정의**: 서비스 수준 목표 및 모니터링 부재
- **대시보드 부족**: Grafana 대시보드 자동화 및 베스트 프랙티스 미적용
- **장기 저장 부재**: Prometheus 로컬 스토리지만 사용, 장기 보관 없음
- **분산 추적 없음**: 마이크로서비스 간 요청 흐름 추적 불가

---

## 2. Observability 3 Pillars 현황 분석

### 2.1 Metrics (메트릭) - 현재 80% 구현

**구현된 기능**
- Prometheus 기반 시계열 데이터 수집
- kube-state-metrics로 Kubernetes 리소스 상태 수집
- node-exporter로 노드 레벨 시스템 메트릭 수집
- 애플리케이션 메트릭 (ojeomneo, reviewmaps) 수집
- ArgoCD 및 인프라 컴포넌트 메트릭 수집

**개선 필요 사항**
- **장기 저장소 부재**: Prometheus 로컬 스토리지 (기본 15일 보존)만 사용
- **고가용성 부족**: Prometheus 단일 인스턴스 (531Mi 메모리)
- **커스텀 메트릭 부족**: 비즈니스 메트릭 (주문 수, 결제 성공률 등) 미정의
- **Recording Rules 미활용**: 자주 쿼리하는 집계 메트릭 사전 계산 부재

### 2.2 Logs (로그) - 현재 10% 구현

**현재 상태**
- 각 Pod의 stdout/stderr 로그만 Kubernetes API로 접근 가능
- 로그 중앙화 시스템 없음
- 로그 검색 및 필터링 불가능
- 로그 보존 정책 없음 (노드 디스크 공간 의존)

**개선 필요 사항 (엔터프라이즈급)**
- **로그 수집**: Promtail 또는 Fluent Bit으로 모든 Pod 로그 수집
- **로그 저장**: Loki (Prometheus for Logs) 또는 Elasticsearch 배포
- **로그 쿼리**: LogQL 또는 Kibana로 강력한 검색 및 분석
- **로그 상관관계**: Trace ID와 로그 연동
- **구조화 로그**: JSON 형식 로그로 필드 기반 검색 지원

### 2.3 Traces (분산 추적) - 현재 5% 구현

**현재 상태**
- OpenTelemetry Collector가 OTLP Traces 수신 중
- 수신한 Traces는 로깅만 하고 버림 (저장소 없음)
- 분산 추적 백엔드 없음

**개선 필요 사항 (엔터프라이즈급)**
- **Tracing 백엔드**: Tempo (Grafana), Jaeger, 또는 Zipkin 배포
- **애플리케이션 계측**: Spring Boot, FastAPI 등에 OpenTelemetry SDK 통합
- **Trace 샘플링**: 프로덕션 부하 고려한 샘플링 정책
- **분산 추적 시각화**: Grafana Tempo UI 또는 Jaeger UI로 요청 플로우 추적
- **Exemplars**: Prometheus 메트릭에서 Trace로 점프 기능

---

## 3. 개선 영역 및 우선순위

### 3.1 우선순위 매트릭스

| 개선 영역 | 비즈니스 영향 | 구현 복잡도 | 우선순위 | 예상 기간 |
|---------|-------------|-----------|---------|----------|
| 로그 집계 (Loki) | 높음 | 중간 | P0 | 1주 |
| 분산 추적 (Tempo) | 높음 | 중간 | P0 | 1주 |
| SLI/SLO 정의 및 모니터링 | 매우 높음 | 낮음 | P0 | 3일 |
| Grafana 대시보드 자동화 | 중간 | 낮음 | P1 | 3일 |
| 장기 메트릭 저장 (Thanos/Mimir) | 중간 | 높음 | P2 | 2주 |
| Error Budget 추적 | 높음 | 중간 | P1 | 1주 |
| On-Call 및 인시던트 관리 | 높음 | 낮음 | P1 | 3일 |
| APM (Application Performance) | 높음 | 중간 | P1 | 1주 |

### 3.2 Phase별 구현 계획

**Phase 1: Observability 3 Pillars 완성 (2주)**
- Loki 배포 및 로그 수집
- Tempo 배포 및 분산 추적 활성화
- 애플리케이션 OpenTelemetry 계측

**Phase 2: SRE 관행 도입 (1주)**
- SLI/SLO 정의 및 PrometheusRule 작성
- Error Budget 대시보드 구축
- On-Call 알림 라우팅 설정

**Phase 3: 고급 기능 (2주)**
- Grafana 대시보드 as Code
- 장기 메트릭 저장소 (Thanos 또는 Mimir)
- 비즈니스 메트릭 및 Recording Rules

---

## 4. 엔터프라이즈급 아키텍처 설계

### 4.1 목표 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│                     애플리케이션 계층                           │
│  [ojeomneo-server] [reviewmaps-server] [ArgoCD] [Istio]    │
│    ↓ OTLP         ↓ OTLP              ↓ Logs              │
└────┬────────────┬─────────────────────┬───────────────────┘
     │            │                     │
     ▼            ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  OpenTelemetry Collector                    │
│  - Traces → Tempo                                           │
│  - Metrics → Prometheus                                     │
│  - Logs → Loki (Promtail 경유)                              │
└─────────────────────────────────────────────────────────────┘
     │            │                     │
     ▼            ▼                     ▼
┌──────────┐ ┌──────────┐       ┌──────────┐
│  Tempo   │ │Prometheus│       │   Loki   │
│ (Traces) │ │(Metrics) │       │  (Logs)  │
└──────────┘ └────┬─────┘       └──────────┘
                  │
                  ▼
            ┌──────────┐
            │  Thanos  │ (장기 저장 - Optional)
            │  Query   │
            └──────────┘
                  │
     ┌────────────┼────────────┐
     ▼            ▼            ▼
┌─────────┐ ┌──────────┐ ┌──────────┐
│ Grafana │ │Alertman- │ │ PagerDuty│
│  (UI)   │ │  ager    │ │ (On-Call)│
└─────────┘ └──────────┘ └──────────┘
```

### 4.2 컴포넌트별 역할 및 설정

#### 4.2.1 Grafana Loki (로그 집계)

**역할**: Prometheus처럼 동작하는 로그 집계 시스템

**배포 방식**
- Helm Chart: `grafana/loki-stack`
- 구성: Loki + Promtail (DaemonSet)
- 저장소: GCP Persistent Disk 100GB (확장 가능)

**주요 설정**
- 로그 보존 기간: 30일 (비용 최적화)
- 압축: gzip 활성화
- 인덱싱: 레이블 기반 (namespace, pod, container, app)
- 쿼리 언어: LogQL

**리소스 요구사항**
- Loki: 512Mi 메모리, 200m CPU
- Promtail (DaemonSet): 128Mi 메모리, 100m CPU per 노드

#### 4.2.2 Grafana Tempo (분산 추적)

**역할**: OpenTelemetry Traces 저장 및 조회

**배포 방식**
- Helm Chart: `grafana/tempo`
- 구성: Tempo Monolithic 모드 (단일 바이너리)
- 저장소: GCP Persistent Disk 50GB

**주요 설정**
- 샘플링 비율: 10% (프로덕션 부하 고려)
- 보존 기간: 7일
- OTLP Receiver: OpenTelemetry Collector 경유
- Exemplars: Prometheus 메트릭과 연동

**리소스 요구사항**
- Tempo: 1Gi 메모리, 500m CPU

#### 4.2.3 Thanos 또는 Grafana Mimir (장기 메트릭 저장)

**역할**: Prometheus 메트릭 장기 저장 및 다중 클러스터 쿼리

**추천**: Grafana Mimir (최신 기술, Cortex 후속)

**배포 방식**
- Helm Chart: `grafana/mimir-distributed`
- 구성: Read/Write 분리 아키텍처
- 저장소: GCS (Google Cloud Storage) - 비용 효율적

**주요 설정**
- Prometheus Remote Write 연동
- 보존 기간: 13개월 (1년 + 1개월 버퍼)
- 압축: 블록 스토리지 최적화
- 쿼리 캐싱: Redis 활용

**리소스 요구사항**
- Mimir Ingester: 2Gi 메모리, 1 CPU
- Mimir Querier: 1Gi 메모리, 500m CPU
- Mimir Store Gateway: 512Mi 메모리, 200m CPU

#### 4.2.4 개선된 OpenTelemetry Collector

**현재 vs 목표 설정 비교**

| 항목 | 현재 설정 | 목표 설정 |
|-----|----------|----------|
| Traces Exporter | logging (버림) | otlp → Tempo |
| Logs Receiver | 없음 | otlp → Loki |
| Sampling | 없음 | Tail-based 샘플링 |
| Processors | batch, resource | batch, resource, attributes, tail_sampling |

**개선 사항**
- Traces를 Tempo로 전송
- Tail-based Sampling으로 에러/지연 요청 100% 보존
- Attributes Processor로 민감 정보 제거 (email, IP 등)

---

## 5. SLI/SLO/SLA 정의

### 5.1 SLI (Service Level Indicator) 정의

**ojeomneo-server**

| SLI | 측정 방법 | 목표 값 |
|-----|----------|--------|
| 가용성 (Availability) | `sum(rate(http_requests_total{status=~"2.."}[5m])) / sum(rate(http_requests_total[5m]))` | 99.5% |
| 응답 시간 (Latency) | `histogram_quantile(0.95, http_request_duration_seconds)` | P95 < 500ms |
| 에러 비율 (Error Rate) | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))` | < 0.5% |

**reviewmaps-server**

| SLI | 측정 방법 | 목표 값 |
|-----|----------|--------|
| 가용성 (Availability) | 동일 | 99.9% |
| 응답 시간 (Latency) | 동일 | P95 < 300ms |
| 에러 비율 (Error Rate) | 동일 | < 0.1% |

### 5.2 SLO (Service Level Objective) 정의

**월별 Error Budget**
- ojeomneo: 99.5% SLO → 0.5% Error Budget → 월 216분 다운타임 허용
- reviewmaps: 99.9% SLO → 0.1% Error Budget → 월 43분 다운타임 허용

**PrometheusRule 예시**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ojeomneo-slo-rules
  namespace: monitoring
spec:
  groups:
  - name: ojeomneo-slo
    interval: 30s
    rules:
    - record: ojeomneo:availability:ratio_rate5m
      expr: |
        sum(rate(http_requests_total{app="ojeomneo-server",status=~"2.."}[5m]))
        /
        sum(rate(http_requests_total{app="ojeomneo-server"}[5m]))

    - alert: OjeomneoBurnRateHigh
      expr: |
        (
          ojeomneo:availability:ratio_rate5m < 0.995
        )
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Ojeomneo SLO 위반 - Error Budget 소진 중"
```

### 5.3 Error Budget 추적 대시보드

**Grafana Panel 구성**
- 현재 Error Budget 잔액 (Gauge)
- 시간별 Error Budget 소진율 (Graph)
- SLO 달성률 (%)
- 최근 SLO 위반 사건 (Table)

---

## 6. On-Call 및 Alerting 전략

### 6.1 알림 라우팅 정책

**Severity 기반 라우팅**

| Severity | 알림 대상 | 알림 방법 | 응답 시간 |
|----------|----------|----------|----------|
| critical | Primary On-Call | PagerDuty → SMS/Call | 15분 |
| warning | Slack #alerts | Slack Notification | 1시간 |
| info | Slack #monitoring | Slack (무음) | 24시간 |

### 6.2 Alertmanager 개선 설정

**현재 문제점**
- SMTP 기반 이메일만 사용 (느림, 놓치기 쉬움)
- 알림 그룹화 및 억제 규칙 부재

**개선 방안**

```yaml
# Alertmanager ConfigMap
receivers:
  - name: 'critical-pager'
    pagerduty_configs:
      - service_key: '<PagerDuty Integration Key>'
        description: '{{ .CommonAnnotations.summary }}'

  - name: 'warning-slack'
    slack_configs:
      - api_url: '<Slack Webhook URL>'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'

route:
  receiver: 'warning-slack'
  routes:
    - match:
        severity: critical
      receiver: 'critical-pager'
      continue: true

    - match:
        severity: warning
      receiver: 'warning-slack'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'namespace']
```

### 6.3 인시던트 관리 프로세스

**자동화 플로우**
1. **Alertmanager** → 알림 발생
2. **PagerDuty** → On-Call 엔지니어 호출
3. **Slack** → 인시던트 채널 자동 생성 (`#incident-YYYY-MM-DD-XXX`)
4. **Grafana** → 인시던트 대시보드 링크 자동 생성
5. **Runbook** → 문제 해결 가이드 자동 표시

---

## 7. Grafana 대시보드 개선

### 7.1 대시보드 as Code (Jsonnet)

**현재 문제점**
- 수동으로 대시보드 생성 및 관리
- 버전 관리 어려움
- 재현성 없음

**개선 방안: Grafonnet (Jsonnet 라이브러리)**

```jsonnet
// dashboards/ojeomneo-overview.jsonnet
local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local prometheus = grafana.prometheus;
local graphPanel = grafana.graphPanel;

dashboard.new(
  'Ojeomneo Service Overview',
  tags=['ojeomneo', 'application'],
  time_from='now-6h',
  refresh='30s',
)
.addPanel(
  graphPanel.new(
    'Request Rate',
    datasource='Prometheus',
    span=6,
  )
  .addTarget(
    prometheus.target(
      'sum(rate(http_requests_total{app="ojeomneo-server"}[5m]))'
    )
  ),
  gridPos={x: 0, y: 0, w: 12, h: 8}
)
```

### 7.2 필수 대시보드 목록

**인프라 대시보드**
- Kubernetes Cluster Overview
- Node Exporter Full
- Persistent Volumes

**애플리케이션 대시보드**
- Ojeomneo Service Health
- Reviewmaps Service Health
- ArgoCD Health

**SRE 대시보드**
- SLO Dashboard (Error Budget, Burn Rate)
- Incident Response Dashboard
- Capacity Planning Dashboard

**3 Pillars 통합 대시보드**
- Metrics + Logs + Traces 상관관계 대시보드
- Exemplars를 통한 메트릭 → Trace 점프

### 7.3 대시보드 프로비저닝 자동화

**Grafana ConfigMap으로 자동 배포**

```yaml
# charts/helm/prod/kube-prometheus-stack/values.yaml
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        folder: ''
        type: file
        options:
          path: /var/lib/grafana/dashboards

  dashboards:
    default:
      ojeomneo-overview:
        url: https://raw.githubusercontent.com/ggorockee/infra/main/dashboards/ojeomneo.json
      reviewmaps-overview:
        url: https://raw.githubusercontent.com/ggorockee/infra/main/dashboards/reviewmaps.json
```

---

## 8. 단계별 구현 계획

### Phase 1: 로그 집계 (Loki) - 1주

**Step 1.1: Loki Stack 배포 (1일)**

- `loki-stack` Helm Chart 설치
- Promtail DaemonSet로 모든 Pod 로그 수집
- Persistent Volume 설정 (100GB)

**Step 1.2: Grafana 연동 (1일)**

- Loki를 Grafana 데이터 소스로 추가
- 기본 로그 탐색 대시보드 생성

**Step 1.3: 로그 쿼리 튜닝 (2일)**

- LogQL 쿼리 최적화
- 로그 레이블 표준화 (app, namespace, pod 등)
- 에러 로그 자동 감지 알림 설정

**Step 1.4: 애플리케이션 로그 구조화 (2일)**

- Spring Boot: Logback JSON 포맷 설정
- FastAPI: Structlog JSON 출력 설정
- 로그 샘플링 (디버그 로그 10% 샘플링)

### Phase 2: 분산 추적 (Tempo) - 1주

**Step 2.1: Tempo 배포 (1일)**

- `tempo` Helm Chart 설치
- OpenTelemetry Collector → Tempo 연동

**Step 2.2: 애플리케이션 계측 (3일)**

- Spring Boot: OpenTelemetry Java Agent 통합
- FastAPI: OpenTelemetry Python SDK 설정
- Trace Context Propagation 설정 (W3C TraceContext)

**Step 2.3: Grafana 연동 및 Exemplars (2일)**

- Tempo를 Grafana 데이터 소스로 추가
- Prometheus Exemplars 활성화
- 메트릭 → Trace 점프 기능 테스트

**Step 2.4: 샘플링 정책 최적화 (1일)**

- Tail-based Sampling: 에러 및 지연 요청 100% 보존
- 정상 요청 10% 샘플링
- 샘플링 비율 동적 조정

### Phase 3: SLI/SLO 구현 - 3일

**Step 3.1: SLI 메트릭 정의 (1일)**

- 애플리케이션에 필요한 메트릭 식별
- PrometheusRule Recording Rules 작성
- 메트릭 검증

**Step 3.2: SLO PrometheusRule 작성 (1일)**

- Burn Rate 알림 규칙 작성
- Multi-Window Multi-Burn-Rate 알고리즘 적용
- Alertmanager 라우팅 설정

**Step 3.3: Error Budget 대시보드 (1일)**

- Grafana 대시보드 생성
- Error Budget 잔액 시각화
- SLO 위반 사건 타임라인

### Phase 4: On-Call 설정 - 3일

**Step 4.1: PagerDuty 연동 (1일)**

- PagerDuty 계정 생성 (무료 티어)
- Alertmanager → PagerDuty Integration
- Escalation Policy 설정

**Step 4.2: Slack 연동 (1일)**

- Slack Webhook 설정
- 알림 채널 분리 (#alerts-critical, #alerts-warning)
- 알림 템플릿 최적화

**Step 4.3: Runbook 작성 (1일)**

- 주요 알림별 대응 매뉴얼 작성
- Grafana 알림에 Runbook URL 링크

### Phase 5: 대시보드 자동화 - 3일

**Step 5.1: Grafonnet 설정 (1일)**

- Jsonnet 환경 구성
- 기본 대시보드 템플릿 작성

**Step 5.2: 대시보드 개발 (2일)**

- Ojeomneo, Reviewmaps 대시보드 Jsonnet 작성
- SLO 대시보드 Jsonnet 작성
- CI/CD 파이프라인으로 자동 배포

### Phase 6 (Optional): 장기 저장소 - 2주

**Step 6.1: Grafana Mimir 배포 (1주)**

- Mimir Helm Chart 설치
- GCS 버킷 생성 및 권한 설정
- Prometheus Remote Write 설정

**Step 6.2: 데이터 마이그레이션 (3일)**

- 기존 Prometheus 데이터 백업
- Mimir로 점진적 전환
- 쿼리 성능 검증

**Step 6.3: 운영 최적화 (3일)**

- Compaction 및 Retention 설정
- Query Frontend 캐싱 튜닝
- 비용 모니터링

---

## 9. 예상 비용 및 리소스

### 9.1 GKE 클러스터 리소스 추가 요구사항

**현재 총 사용량**
- CPU: 90m (Prometheus) + 35m (OTEL) + 기타 = 약 500m
- Memory: 531Mi (Prometheus) + 278Mi (Grafana) + 기타 = 약 2Gi

**추가 필요 리소스**

| 컴포넌트 | CPU | Memory | PV Storage |
|---------|-----|--------|------------|
| Loki | 200m | 512Mi | 100GB |
| Promtail (3 노드) | 300m | 384Mi | - |
| Tempo | 500m | 1Gi | 50GB |
| Grafana Mimir (Optional) | 2000m | 4Gi | - |
| **합계 (Mimir 제외)** | **1000m (1 CPU)** | **1.9Gi** | **150GB** |
| **합계 (Mimir 포함)** | **3000m (3 CPU)** | **5.9Gi** | **150GB** |

### 9.2 GCP 비용 추정

**GKE 노드 비용** (기존 노드에 추가 가능 여부 확인 필요)
- 현재 노드 타입: n1-standard-2 (2 vCPU, 7.5GB RAM)
- 추가 노드 필요 여부: 기존 노드 리소스 여유에 따라 결정
- 만약 노드 추가 필요 시: $0.095/hour × 730시간 = **$69.35/월** per 노드

**Persistent Disk 비용**
- Loki: 100GB × $0.04/GB = $4/월
- Tempo: 50GB × $0.04/GB = $2/월
- **합계: $6/월**

**Cloud Storage (Mimir 사용 시)**
- 예상 메트릭 데이터: 100GB/월 × $0.020/GB = $2/월
- **합계: $2/월**

**총 추가 비용 (최소 구성)**
- PV만 사용 (Mimir 없음): **$6/월**
- 노드 추가 없이 기존 노드 사용: **$0~6/월**

**총 추가 비용 (Mimir 포함)**
- PV + GCS: **$8/월**
- 노드 추가 1대 필요 시: **$77/월**

### 9.3 외부 서비스 비용

| 서비스 | 플랜 | 월 비용 |
|--------|------|--------|
| PagerDuty | Free (1 사용자) | $0 |
| PagerDuty | Professional | $25/사용자 |
| Slack | Free | $0 |
| Slack | Pro | $7.25/사용자 |
| **합계 (무료 플랜)** | | **$0** |

### 9.4 1인 개발자 추천 구성

**최소 비용 엔터프라이즈급 구성**
- Loki + Tempo 배포 (Mimir 제외)
- 기존 GKE 노드 활용 (추가 노드 없음)
- PagerDuty 무료 플랜
- Slack 무료 플랜
- **총 비용: $6/월 (PV 비용만)**

**장기 운영 추천 구성**
- Loki + Tempo + Mimir
- GKE 노드 1대 추가 (n1-standard-2)
- PagerDuty Professional
- Slack Pro
- **총 비용: $109.25/월**

---

## 10. 성공 기준 및 KPI

### 10.1 기술적 성공 기준

- **Observability 3 Pillars 완성**: Metrics, Logs, Traces 모두 수집 및 시각화
- **SLO 달성률 추적**: 모든 서비스 99% 이상 SLO 달성 모니터링
- **MTTD (Mean Time To Detect)**: 5분 이내 장애 감지
- **MTTR (Mean Time To Resolve)**: 30분 이내 장애 해결
- **알림 정확도**: False Positive < 10%

### 10.2 비즈니스 성공 기준

- **인시던트 감소**: 월별 인시던트 수 50% 감소
- **다운타임 감소**: Error Budget 초과 0회
- **개발 속도 향상**: 로그/추적으로 디버깅 시간 70% 단축
- **고객 신뢰 향상**: 장애 발생 시 사전 알림 및 빠른 복구

### 10.3 엔터프라이즈 인정 기준

기업에서 인정받을 수 있는 수준의 Observability 시스템이 되기 위한 체크리스트:

- [x] Prometheus + Grafana 기본 스택
- [ ] 로그 중앙화 (Loki 또는 Elasticsearch)
- [ ] 분산 추적 (Tempo, Jaeger, Zipkin)
- [ ] SLI/SLO 정의 및 모니터링
- [ ] Error Budget 추적 및 경고
- [ ] On-Call 및 인시던트 관리 프로세스
- [ ] 대시보드 as Code (Jsonnet, Terraform)
- [ ] 장기 메트릭 저장 (Thanos, Mimir)
- [ ] APM (애플리케이션 성능 모니터링)
- [ ] 알림 정책 및 Runbook 문서화

---

## 11. 다음 단계

### 11.1 즉시 시작 가능한 작업 (비용 0원)

1. **SLI/SLO 정의**: 코드만으로 가능 (PrometheusRule YAML)
2. **Grafana 대시보드 개선**: 기존 Grafana에 대시보드 추가
3. **Alertmanager 설정 개선**: 알림 그룹화 및 억제 규칙 추가
4. **Runbook 작성**: Markdown 문서로 대응 매뉴얼 작성

### 11.2 우선순위 구현 순서

**주 1: Loki 배포**
- 로그 중앙화로 즉시 디버깅 생산성 향상
- 비용: $4/월 (100GB PV)

**주 2: Tempo 배포**
- 분산 추적으로 마이크로서비스 간 호출 파악
- 비용: $2/월 (50GB PV)

**주 3: SLO 구현**
- Error Budget 추적으로 서비스 품질 관리
- 비용: $0 (코드만)

**주 4~5: 대시보드 자동화**
- Grafonnet으로 재현 가능한 대시보드 관리
- 비용: $0 (코드만)

**주 6 이후: Mimir 검토**
- 장기 메트릭 저장이 필요해지면 고려
- 비용: $2/월 (GCS) + 노드 비용

### 11.3 학습 리소스

**공식 문서**
- Grafana Loki: https://grafana.com/docs/loki/latest/
- Grafana Tempo: https://grafana.com/docs/tempo/latest/
- OpenTelemetry: https://opentelemetry.io/docs/
- SLO/SLI: https://sre.google/workbook/implementing-slos/

**예제 저장소**
- Grafana Monitoring Stack: https://github.com/grafana/tns
- OpenTelemetry Demo: https://github.com/open-telemetry/opentelemetry-demo

---

## 12. 결론

현재 Kubernetes 클러스터는 **Metrics (메트릭)** 영역에서 80% 완성도를 보이지만, **Logs (로그)**와 **Traces (분산 추적)**가 거의 구현되지 않아 완전한 Observability를 달성하지 못했습니다.

엔터프라이즈급 Observability 시스템을 구축하기 위해서는:
1. **Loki로 로그 중앙화**
2. **Tempo로 분산 추적 활성화**
3. **SLI/SLO 정의 및 Error Budget 추적**
4. **On-Call 및 인시던트 관리 프로세스 도입**
5. **대시보드 as Code로 재현 가능한 관리**

이 계획을 단계적으로 구현하면 **월 $6~109의 비용**으로 기업에서 인정받을 수 있는 수준의 Observability 시스템을 구축할 수 있습니다.

**최종 추천**: Phase 1~3 (Loki, Tempo, SLO)을 먼저 구현하여 3 Pillars를 완성하고, Phase 4~6은 운영 경험을 쌓은 후 순차적으로 도입하는 것을 권장합니다.

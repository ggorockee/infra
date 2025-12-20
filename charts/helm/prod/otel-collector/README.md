# OpenTelemetry Collector for ReviewMaps

ReviewMaps 애플리케이션의 OpenTelemetry 메트릭을 수집하여 Prometheus와 SigNoz로 전송하는 Collector입니다.

## 아키텍처

| 구성요소 | 역할 |
|----------|------|
| ReviewMaps Server | Go Fiber API 서버, OTLP HTTP로 메트릭 전송 |
| Go-scraper | CronJob으로 실행되는 스크래퍼, OTLP HTTP로 메트릭 전송 |
| **OTel Collector** | OTLP 메트릭 수신 → Prometheus/SigNoz로 전송 |
| Prometheus | Collector의 `/metrics` 엔드포인트 스크레이핑 |
| Grafana | Prometheus 데이터 시각화 |

## 데이터 흐름

```
┌─────────────────┐
│ Server (Fiber)  │──┐
└─────────────────┘  │
                     │ OTLP HTTP
┌─────────────────┐  │ (port 4318)
│ Go-scraper      │──┤
│ (CronJob)       │  │
└─────────────────┘  │
                     ▼
              ┌──────────────┐
              │ OTel         │
              │ Collector    │
              └──────────────┘
                     │
              ┌──────┴──────┐
              ▼             ▼
         Prometheus      SigNoz
         (scrape)        (push)
              │
              ▼
          Grafana
```

## 주요 기능

### 1. OTLP Receiver
- **HTTP**: `0.0.0.0:4318`
- **gRPC**: `0.0.0.0:4317`
- 애플리케이션에서 push된 메트릭 수신

### 2. Processors
- **Batch Processor**: 메트릭 배치 처리 (10초, 1024개)
- **Resource Processor**: 환경 라벨 추가 (environment, cluster)

### 3. Exporters
- **Prometheus Exporter**: `0.0.0.0:8889/metrics` 엔드포인트 노출
- **OTLP HTTP Exporter**: SigNoz로 메트릭 전송 (선택사항)
- **Logging Exporter**: 디버깅용 로깅

### 4. ServiceMonitor
- Prometheus가 자동으로 Collector 메트릭 수집
- 네임스페이스 간 모니터링 지원

## 배포 방법

### 1. ArgoCD로 배포 (권장)

ArgoCD Application이 자동으로 생성됩니다.

```bash
# ArgoCD 설정 확인
kubectl get application -n argocd otel-collector

# 동기화 상태 확인
kubectl get application -n argocd otel-collector -o jsonpath='{.status.sync.status}'
```

### 2. Helm으로 직접 배포

```bash
cd /Users/woohyeon/ggorockee/infra/charts/helm/prod/otel-collector

# values 파일 확인
cat values.yaml

# 배포
helm install otel-collector . \
  --namespace monitoring \
  --create-namespace \
  -f values.yaml
```

## 설정 확인

### 1. Pod 상태 확인

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=otel-collector

# 로그 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=otel-collector --tail=100
```

### 2. Service 확인

```bash
kubectl get svc -n monitoring otel-collector

# 예상 출력:
# NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
# otel-collector   ClusterIP   10.x.x.x        <none>        4318/TCP,4317/TCP,8889/TCP,13133/TCP
```

### 3. ServiceMonitor 확인

```bash
kubectl get servicemonitor -n monitoring otel-collector

# Prometheus가 인식했는지 확인
kubectl get prometheus -n monitoring -o yaml | grep -A 5 serviceMonitorSelector
```

### 4. 메트릭 수집 확인

Prometheus에서 확인:

```promql
# Collector 메트릭 확인
{job="otel-collector"}

# ReviewMaps 애플리케이션 메트릭 확인
{namespace="reviewmaps"}

# Server HTTP 메트릭
http_requests_total{job="reviewmaps-server"}

# Scraper 메트릭
scraper_scrape_duration{job="go-scraper"}
```

## 트러블슈팅

### 1. 메트릭이 수집되지 않음

**문제**: Prometheus에 메트릭이 보이지 않음

**확인 사항**:

```bash
# 1. Collector Pod 상태 확인
kubectl get pods -n monitoring -l app.kubernetes.io/name=otel-collector

# 2. Collector 로그 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=otel-collector | grep -i error

# 3. ServiceMonitor 확인
kubectl get servicemonitor -n monitoring otel-collector -o yaml

# 4. Prometheus Targets 확인
# Prometheus UI → Status → Targets에서 otel-collector 확인
```

### 2. 애플리케이션이 Collector에 연결 실패

**문제**: Server/Go-scraper 로그에 OTLP 연결 에러

**확인 사항**:

```bash
# 1. Collector Service 존재 확인
kubectl get svc -n monitoring otel-collector

# 2. 네임스페이스 간 통신 확인
kubectl run -it --rm debug --image=busybox --restart=Never -n reviewmaps -- \
  nslookup otel-collector.monitoring.svc.cluster.local

# 3. 애플리케이션 환경변수 확인
kubectl get configmap -n reviewmaps reviewmaps-server -o yaml | grep OTEL
```

### 3. Collector가 시작되지 않음

**문제**: Collector Pod가 CrashLoopBackOff 상태

**확인 사항**:

```bash
# 1. Pod 이벤트 확인
kubectl describe pod -n monitoring -l app.kubernetes.io/name=otel-collector

# 2. ConfigMap 문법 확인
kubectl get configmap -n monitoring otel-collector-config -o yaml

# 3. 리소스 부족 확인
kubectl top nodes
kubectl top pods -n monitoring
```

## 성능 튜닝

### 리소스 조정

메트릭 양에 따라 리소스를 조정할 수 있습니다:

```yaml
resources:
  requests:
    cpu: 200m      # 기본: 100m
    memory: 256Mi  # 기본: 128Mi
  limits:
    cpu: 1000m     # 기본: 500m
    memory: 1Gi    # 기본: 512Mi
```

### Batch Processor 튜닝

```yaml
processors:
  batch:
    timeout: 5s           # 기본: 10s (메트릭 전송 빈도 증가)
    send_batch_size: 2048 # 기본: 1024 (배치 크기 증가)
```

### 스크레이프 간격 조정

```yaml
serviceMonitor:
  enabled: true
  interval: 15s        # 기본: 30s (더 자주 수집)
  scrapeTimeout: 10s
```

## 모니터링

### Collector 자체 메트릭

Collector는 자체 성능 메트릭을 노출합니다:

```promql
# Collector가 수신한 메트릭 수
otelcol_receiver_accepted_metric_points

# Collector가 전송한 메트릭 수
otelcol_exporter_sent_metric_points

# Collector 메모리 사용량
process_resident_memory_bytes{job="otel-collector"}
```

### Grafana 대시보드

Prometheus에서 다음 대시보드를 생성할 수 있습니다:

1. **ReviewMaps Server 대시보드**
   - HTTP 요청 수: `http_requests_total`
   - HTTP 요청 지연시간: `http_request_duration_seconds`
   - 활성 요청 수: `http_active_requests`

2. **Go-scraper 대시보드**
   - 스크래핑 지연시간: `scraper_scrape_duration`
   - 수집된 캠페인 수: `scraper_campaigns_scraped`
   - 에러 수: `scraper_scrape_errors`

3. **OTel Collector 대시보드**
   - 수신/전송 메트릭
   - 리소스 사용량
   - 에러율

## 네임스페이스 간 모니터링

Prometheus는 `serviceMonitorSelectorNilUsesHelmValues: false` 설정으로 모든 네임스페이스의 ServiceMonitor를 자동으로 발견합니다.

**현재 설정**:

```yaml
# kube-prometheus-stack/values-override.yaml
prometheus:
  prometheusSpec:
    podMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
```

이 설정으로 `monitoring` 네임스페이스의 Prometheus가 `reviewmaps` 네임스페이스의 애플리케이션을 모니터링할 수 있습니다.

## 참고 자료

- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Prometheus Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusexporter)
- [ServiceMonitor CRD](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/user-guides/getting-started.md)

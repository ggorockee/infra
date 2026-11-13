# Grafana 대시보드

Prometheus 메트릭 모니터링을 위한 Grafana 대시보드 JSON 파일입니다.

## 대시보드 목록

### ReviewMaps HTTP Metrics
- 파일: `reviewmaps-dashboard.json`
- UID: `reviewmaps-http-metrics`
- 메트릭 Prefix: `reviewmaps_`

**포함된 패널**:
- Request Rate (RPS): 초당 요청 수
- Response Time (Latency): P50, P95, P99 응답 시간
- Error Rate (5xx): 5xx 에러율
- Active Connections: 현재 활성 연결 수
- Request/Response Size: 평균 요청/응답 크기
- HTTP Status Codes: HTTP 상태 코드별 요청 수
- Endpoint Summary: 엔드포인트별 RPS 및 P95 지연시간 요약

### ReviewMaps CronJob & DB 적재
- 파일: `reviewmaps-cronjob-dashboard.json`
- UID: `reviewmaps-cronjob`
- 데이터소스: Prometheus(kube-state-metrics), ReviewMaps-DB(Cloud SQL PostgreSQL)

**포함된 패널**:
- CronJob별 마지막 성공 후 경과 시간, 다음 실행 예정, 실패/실행 중 Job 수
- Job 실행 구간 타임라인, 최근 Job 실행 시간
- 오늘(KST) 적재 건수, 활성 캠페인 수, 마지막 적재 시각
- 마감 지난 잔존 캠페인 수 (cleanup soft delete 검증)
- 오늘 플랫폼별 적재 건수, 플랫폼별 마지막 적재 시각, 최근 14일 갱신일 분포

### 클러스터 전체 현황
- 파일: `cluster-overview-dashboard.json`
- UID: `cluster-overview`
- 데이터소스: Prometheus (node-exporter, kube-state-metrics, Istio gateway, blackbox exporter, postgres-exporter, ArgoCD, cert-manager, External Secrets)

**포함된 패널**:
- 발생 중 알림 (등급별 수, 목록), 서비스 접속 상태 (외부 URL 12개 · 내부 Redis 3개)
- 노드 CPU/메모리/디스크, 클러스터 requests 예약률
- 사용 불가 워크로드, 비정상 Pod, 컨테이너 재시작, 메모리 limit 대비 사용률, PVC 사용률
- 서비스별 요청 수·5xx·4xx·P95 (Istio gateway)
- 접속 시간, HTTPS 인증서 남은 일수
- ArgoCD 앱 상태, 인증서/ExternalSecret/Istio 설정 오류
- Cloud SQL 접속·연결 수·DB 크기·캐시 적중률·트랜잭션

### Ojeomneo HTTP Metrics
- 파일: `ojeomneo-dashboard.json`
- UID: `ojeomneo-http-metrics`
- 메트릭 Prefix: `ojeomneo_`

**포함된 패널**: ReviewMaps와 동일

## 자동 배포

이 디렉터리의 JSON은 `templates/grafana/configmap-custom-dashboards.yaml`이 ConfigMap으로 만들고 Grafana sidecar가 자동 로드합니다. 아래 수동 Import는 로컬 테스트용입니다.

## Grafana 대시보드 Import 방법

### 1. Grafana UI에서 Import

1. Grafana에 로그인
2. 좌측 메뉴에서 **Dashboards** → **Import** 클릭
3. **Upload JSON file** 버튼 클릭
4. 대시보드 JSON 파일 선택:
   - `reviewmaps-dashboard.json`
   - `ojeomneo-dashboard.json`
5. Prometheus 데이터소스 선택
6. **Import** 버튼 클릭

### 2. Grafana API를 통한 Import

```bash
# Grafana 접속
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# ReviewMaps 대시보드 Import
curl -X POST http://admin:prom-operator@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @reviewmaps-dashboard.json

# Ojeomneo 대시보드 Import
curl -X POST http://admin:prom-operator@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @ojeomneo-dashboard.json
```

**참고**: Grafana 기본 admin 비밀번호는 Secret에서 확인:
```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode
```

### 3. ConfigMap을 통한 자동 Import (권장)

Grafana는 ConfigMap을 통해 대시보드를 자동으로 로드할 수 있습니다.

```bash
# ConfigMap 생성
kubectl create configmap grafana-dashboards \
  --from-file=reviewmaps-dashboard.json \
  --from-file=ojeomneo-dashboard.json \
  -n monitoring

# Grafana values.yaml에 다음 설정 추가:
# dashboardProviders:
#   dashboardproviders.yaml:
#     apiVersion: 1
#     providers:
#     - name: 'default'
#       orgId: 1
#       folder: ''
#       type: file
#       disableDeletion: false
#       editable: true
#       options:
#         path: /var/lib/grafana/dashboards/default
#
# dashboards:
#   default:
#     reviewmaps:
#       json: |
#         (paste reviewmaps-dashboard.json content)
#     ojeomneo:
#       json: |
#         (paste ojeomneo-dashboard.json content)
```

## 대시보드 메트릭 설명

### Counter 메트릭
- `reviewmaps_http_requests_total`: HTTP 요청 총 횟수 (method, path, status 라벨)
- `ojeomneo_http_requests_total`: HTTP 요청 총 횟수 (method, path, status 라벨)

### Histogram 메트릭
- `reviewmaps_http_request_duration_seconds`: HTTP 요청 지연시간 (method, path 라벨)
- `ojeomneo_http_request_duration_seconds`: HTTP 요청 지연시간 (method, path 라벨)

### Gauge 메트릭
- `reviewmaps_http_active_connections`: 현재 활성 HTTP 연결 수
- `ojeomneo_http_active_connections`: 현재 활성 HTTP 연결 수

### Summary 메트릭
- `reviewmaps_http_request_size_bytes`: HTTP 요청 크기 (method, path 라벨)
- `reviewmaps_http_response_size_bytes`: HTTP 응답 크기 (method, path 라벨)
- `ojeomneo_http_request_size_bytes`: HTTP 요청 크기 (method, path 라벨)
- `ojeomneo_http_response_size_bytes`: HTTP 응답 크기 (method, path 라벨)

## PromQL 쿼리 예시

**Request Rate (초당 요청 수)**:
```promql
rate(reviewmaps_http_requests_total[5m])
rate(ojeomneo_http_requests_total[5m])
```

**P95 Response Time**:
```promql
histogram_quantile(0.95, rate(reviewmaps_http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(ojeomneo_http_request_duration_seconds_bucket[5m]))
```

**Error Rate**:
```promql
sum(rate(reviewmaps_http_requests_total{status=~"5.."}[5m]))
  / sum(rate(reviewmaps_http_requests_total[5m]))

sum(rate(ojeomneo_http_requests_total{status=~"5.."}[5m]))
  / sum(rate(ojeomneo_http_requests_total[5m]))
```

## 대시보드 커스터마이징

대시보드를 커스터마이징하려면:
1. Grafana UI에서 대시보드 수정
2. 우측 상단 설정(톱니바퀴) 아이콘 → **JSON Model** 클릭
3. JSON 복사
4. 해당 JSON 파일에 붙여넣기
5. Git에 커밋

## 주의사항

- 대시보드 UID는 고유해야 합니다 (충돌 시 Import 실패)
- Prometheus 데이터소스 UID가 `prometheus`가 아닌 경우, JSON에서 수정 필요
- 시간대(Timezone)는 `Asia/Seoul`로 설정되어 있습니다
- 새로고침 주기는 30초로 설정되어 있습니다

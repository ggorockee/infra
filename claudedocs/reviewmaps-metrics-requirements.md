# ReviewMaps 커스텀 메트릭 개발 요청서

## 배경
Grafana 대시보드에서 "No data" 상태인 패널들이 있습니다. PR #105에서 커스텀 메트릭을 구현했으나, 일부 메트릭이 아직 데이터를 노출하지 않습니다.

## 분석 결과

### 백엔드 메트릭 구현 확인 (reviewmaps 서버)

| 파일 | 상태 | 비고 |
|------|------|------|
| `core/metrics.py` | ✅ 구현됨 | 모든 메트릭 정의 완료 |
| `core/middleware/metrics.py` | ✅ 구현됨 | API 요청/예외 추적 |
| `core/management/commands/collect_metrics.py` | ✅ 구현됨 | Gauge 수집 명령어 |

### 핵심 문제: `app` 라벨 누락

현재 메트릭 정의에 `app` 라벨이 없어 Grafana `$application` 변수 필터링이 작동하지 않습니다.

**현재 상태 (문제):**
```python
campaign_active_total = Gauge(
    'reviewmaps_campaign_active_total',
    '현재 활성 캠페인 수',
    ['region']  # app 라벨 없음
)
```

**필요한 상태:**
```python
campaign_active_total = Gauge(
    'reviewmaps_campaign_active_total',
    '현재 활성 캠페인 수',
    ['region', 'app']  # app 라벨 추가 필요
)
```

## 필요한 액션

### 1. [infra] Gauge 메트릭 수집 CronJob 추가 ✅
이 PR에서 Helm 차트에 CronJob 추가 완료:
- 위치: `charts/helm/prod/reviewmaps/charts/server/templates/metrics-cronjob.yaml`
- 스케줄: 5분마다 실행 (`*/5 * * * *`)

### 2. [reviewmaps 서버] `app` 라벨 추가 필요 ⚠️

**수정 필요 파일:**

#### `core/metrics.py` - 모든 메트릭에 `app` 라벨 추가
```python
# 예시: campaign_active_total
campaign_active_total = Gauge(
    'reviewmaps_campaign_active_total',
    '현재 활성 캠페인 수',
    ['region', 'app']  # app 라벨 추가
)
```

#### `core/middleware/metrics.py` - 메트릭 기록 시 `app` 라벨 포함
```python
# 예시: record_api_request 호출 시
record_api_request(
    method=request.method,
    endpoint=endpoint,
    status=status,
    duration=duration,
    app='reviewmaps-server'  # app 라벨 추가
)
```

#### `core/management/commands/collect_metrics.py` - Gauge 설정 시 `app` 라벨 포함
```python
# 예시: campaign_active_total 설정 시
campaign_active_total.labels(region=region, app='reviewmaps-server').set(count)
```

### 3. 영향받는 메트릭 목록

| 메트릭 | 타입 | 현재 라벨 | 추가 필요 |
|--------|------|----------|----------|
| `reviewmaps_service_up` | Gauge | `service` | `app` |
| `reviewmaps_active_users_total` | Gauge | 없음 | `app` |
| `reviewmaps_fcm_devices_active_total` | Gauge | `device_type` | `app` |
| `reviewmaps_campaign_active_total` | Gauge | `region` | `app` |
| `reviewmaps_campaign_expired_total` | Counter | `region` | `app` |
| `reviewmaps_api_requests_total` | Counter | `method, endpoint, status` | `app` |
| `reviewmaps_api_request_duration_seconds` | Histogram | `method, endpoint` | `app` |
| `reviewmaps_exceptions_total` | Counter | `exception_type, view_name` | `app` |
| `reviewmaps_table_rows_total` | Gauge | `table_name` | `app` |
| `reviewmaps_table_size_bytes` | Gauge | `table_name` | `app` |

## 검증 방법

배포 후 메트릭 확인:
```bash
# Pod에서 메트릭 확인
kubectl exec -it -n reviewmaps deployments/reviewmaps-server -- curl -s localhost:8000/metrics | grep reviewmaps_

# app 라벨 포함 여부 확인
kubectl exec -it -n reviewmaps deployments/reviewmaps-server -- curl -s localhost:8000/metrics | grep 'app="reviewmaps-server"'

# CronJob 실행 후 확인
kubectl get cronjobs -n reviewmaps
kubectl logs -n reviewmaps job/reviewmaps-server-metrics-collector-xxxxx
```

## 변경된 파일 목록

### 이 PR에서 수정 (infra 레포)
1. `grafana-django-reviewmaps.json` - 대시보드 쿼리에 fallback 패턴 추가
2. `charts/helm/prod/reviewmaps/charts/server/templates/metrics-cronjob.yaml` - 신규 생성
3. `charts/helm/prod/reviewmaps/charts/server/values.yaml` - metrics.collector 설정 추가
4. `charts/helm/prod/reviewmaps/values.yaml` - metrics.collector 활성화
5. `claudedocs/reviewmaps-metrics-requirements.md` - 개발 요청 문서

### 백엔드에서 수정 필요 (reviewmaps 레포)
- `core/metrics.py` - 모든 메트릭에 `app` 라벨 추가
- `core/middleware/metrics.py` - `app` 라벨 포함하여 메트릭 기록
- `core/management/commands/collect_metrics.py` - `app` 라벨 포함하여 Gauge 설정

## 테스트 체크리스트
- [ ] Helm 차트 배포 후 CronJob 생성 확인
- [ ] CronJob 실행 후 Gauge 메트릭 수집 확인
- [ ] 모든 커스텀 메트릭에 `app` 라벨 포함 확인
- [ ] Grafana 대시보드에서 "No data" 패널 해소 확인
- [ ] `$application` 변수 필터링 정상 작동 확인

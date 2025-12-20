# Prometheus 메트릭 수집 구현 계획서

**작성일**: 2025-12-20
**작성자**: Claude (AI Assistant)
**대상 애플리케이션**: ReviewMaps, Ojeomneo
**목표**: Prometheus를 통한 애플리케이션 메트릭 수집 활성화

---

## 📋 목차

- [현재 상태 분석](#현재-상태-분석)
- [Phase 1: 오점너 ServiceMonitor 활성화](#phase-1-오점너-servicemonitor-활성화)
- [Phase 2: 리뷰맵 Prometheus 엔드포인트 구현](#phase-2-리뷰맵-prometheus-엔드포인트-구현)
- [Phase 3: 모니터링 대시보드 구성](#phase-3-모니터링-대시보드-구성)
- [검증 체크리스트](#검증-체크리스트)
- [롤백 계획](#롤백-계획)

---

## 현재 상태 분석

### Kubernetes 인프라

| 리소스 | 상태 | 비고 |
|--------|------|------|
| Prometheus Stack | ✅ 정상 | monitoring 네임스페이스 |
| ArgoCD | ✅ 정상 | 자동 sync 활성화 |
| reviewmaps Pods | ✅ Running | 3개 Pod 정상 운영 |
| ojeomneo Pods | ✅ Running | 4개 Pod 정상 운영 |

### 애플리케이션 메트릭 현황

| 항목 | ReviewMaps | Ojeomneo |
|------|------------|----------|
| **Helm ServiceMonitor 템플릿** | ✅ 존재 | ✅ 존재 |
| **values.yaml metrics.enabled** | ✅ true | ✅ true |
| **values.yaml serviceMonitor.enabled** | ❌ false | ❌ false |
| **서버 메트릭 엔드포인트** | ❌ 미구현 | ✅ 구현 완료 |
| **ServiceMonitor 배포 상태** | ❌ 없음 | ❌ 없음 |
| **Prometheus 메트릭 수집** | ❌ 불가능 | ❌ 불가능 |

### 메트릭 구현 상세

**ReviewMaps**:
- OpenTelemetry 메트릭만 구현 (SigNoz 전송)
- Prometheus `/metrics` 엔드포인트 없음
- Go Fiber 프레임워크 사용

**Ojeomneo**:
- Prometheus 메트릭 완벽 구현 (`/ojeomneo/metrics`)
- OpenTelemetry 메트릭도 구현
- Go Fiber 프레임워크 사용
- 5가지 메트릭 수집 준비 완료

### 포트 및 서비스 정보

| 애플리케이션 | 포트 | 포트명 | 프레임워크 | 메트릭 경로 |
|--------------|------|--------|------------|-------------|
| ReviewMaps Server | 3000 | `http` | Go Fiber | `/metrics` (구현 필요) |
| Ojeomneo Server | 3000 | `fiber` | Go Fiber | `/ojeomneo/metrics` |
| ReviewMaps Admin | 8000 | `django` | Django | - |
| Ojeomneo Admin | 8000 | `django` | Django | - |

---

## CI/CD 파이프라인 및 배포 프로세스

### 서버 코드 변경 시 (Phase 2 해당)

**프로세스**:
1. 서버 레포 (reviewmaps-server 또는 ojeomneo-server) feature 브랜치 작업
2. PR 생성 및 main 브랜치 병합
3. GitHub Actions 자동 실행:
   - Docker 이미지 빌드 및 푸시
   - infra 레포에 feature 브랜치 생성 및 이미지 태그 업데이트
   - infra 레포 PR 자동 병합 (auto-merge)
4. **ArgoCD 강제 Sync 필요** (자동 감지 시간이 오래 걸림)

**ArgoCD 강제 Sync 방법**:
- **kubectl 사용**: `kubectl patch app <app-name> -n argocd -p '{"operation":{"sync":{}}}' --type merge`
  - Ojeomneo: `kubectl patch app ojeomneo -n argocd -p '{"operation":{"sync":{}}}' --type merge`
  - ReviewMaps: `kubectl patch app reviewmaps -n argocd -p '{"operation":{"sync":{}}}' --type merge`
- **UI 사용**: ArgoCD 대시보드에서 해당 Application 선택 후 "Sync" 버튼 클릭

### Helm Chart 변경 시 (Phase 1 해당)

**프로세스**:
1. infra 레포 feature 브랜치 생성
2. `charts/helm/prod/` 하위 values.yaml 수정
3. PR 생성 및 main 브랜치 병합
4. **ArgoCD 강제 Sync 필요** (시간 단축)

**중요**: 모든 Helm Chart는 ArgoCD로 통제되므로, 변경사항 적용을 위해서는 반드시 ArgoCD Sync 필요

---

## 배포 시간 최적화 전략

| 단계 | 기존 방식 | 최적화 방식 | 시간 절감 |
|------|-----------|-------------|-----------|
| 코드 변경 후 배포 | ArgoCD 자동 감지 대기 (5-10분) | 강제 Sync 즉시 실행 | 5-10분 |
| Helm Chart 변경 | ArgoCD 자동 감지 대기 (3-5분) | 강제 Sync 즉시 실행 | 3-5분 |

**권장사항**:
- infra 레포 main 병합 후 즉시 ArgoCD Sync 실행
- CI/CD 파이프라인 완료 모니터링 후 수동 Sync


## Phase 1: 오점너 ServiceMonitor 활성화

**예상 소요 시간**: 15분 (ArgoCD 강제 Sync 사용)
**난이도**: ⭐ (낮음)
**리스크**: 낮음 (코드 변경 없음, 기존 메트릭 활성화만)

### 1.1 작업 체크리스트

- [ ] infra 레포 Feature 브랜치 생성
- [ ] `charts/helm/prod/ojeomneo/values.yaml` 수정
- [ ] Git 커밋 및 푸시
- [ ] GitHub PR 생성 및 main 병합
- [ ] **ArgoCD 강제 Sync 실행** (kubectl 또는 UI 사용)
- [ ] ServiceMonitor 배포 확인
- [ ] Prometheus Targets 확인
- [ ] 메트릭 수집 검증

### 1.2 수정 대상 파일

**파일**: `charts/helm/prod/ojeomneo/values.yaml`
**위치**: Line 137
**변경 전**:
```
serviceMonitor:
  enabled: false
```

**변경 후**:
```
serviceMonitor:
  enabled: true
```

### 1.3 Git 워크플로우

**브랜치명**: `feature/enable-ojeomneo-prometheus-metrics`

**커밋 메시지 템플릿**:
```
feat(ojeomneo): Prometheus ServiceMonitor 활성화

- serviceMonitor.enabled를 true로 변경
- Prometheus가 /ojeomneo/metrics 엔드포인트 수집 시작
- 기존 구현된 메트릭 활성화 (5가지 메트릭)
```

**배포 절차**:
1. Feature 브랜치 생성: `git checkout -b feature/enable-ojeomneo-prometheus-metrics`
2. values.yaml 수정
3. Git 커밋 및 푸시: `git add . && git commit && git push origin feature/enable-ojeomneo-prometheus-metrics`
4. GitHub PR 생성 및 main 병합
5. **ArgoCD 강제 Sync**:
   - kubectl: `kubectl patch app ojeomneo -n argocd -p '{"operation":{"sync":{}}}' --type merge`
   - 또는 ArgoCD UI에서 ojeomneo Application 선택 후 Sync 버튼 클릭

### 1.4 검증 방법

**Step 1**: ServiceMonitor 리소스 확인
- 명령어: `kubectl get servicemonitors -n ojeomneo`
- 예상 결과: `ojeomneo-server` 리소스 생성됨

**Step 2**: Prometheus Targets 확인
- 명령어: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090`
- 브라우저: `http://localhost:9090/targets`
- 확인사항: `ojeomneo/ojeomneo-server` Target이 UP 상태

**Step 3**: 메트릭 수집 확인
- Prometheus UI에서 PromQL 쿼리 실행
- 쿼리 예시:
  - `ojeomneo_http_requests_total`
  - `ojeomneo_http_request_duration_seconds`
  - `ojeomneo_http_active_connections`

**Step 4**: 메트릭 라벨 확인
- 쿼리: `ojeomneo_http_requests_total{method="GET"}`
- 확인사항: method, path, status 라벨 정상 수집

### 1.5 예상 결과

| 메트릭명 | 타입 | 설명 |
|---------|------|------|
| ojeomneo_http_requests_total | Counter | HTTP 요청 수 (method, path, status) |
| ojeomneo_http_request_duration_seconds | Histogram | HTTP 응답 시간 |
| ojeomneo_http_active_connections | Gauge | 활성 연결 수 |
| ojeomneo_http_request_size_bytes | Summary | 요청 크기 |
| ojeomneo_http_response_size_bytes | Summary | 응답 크기 |

### 1.6 롤백 방법

**문제 발생 시**:
- ArgoCD에서 이전 Revision으로 롤백
- 또는 values.yaml에서 `serviceMonitor.enabled: false`로 재변경

**롤백 명령어**:
- `kubectl delete servicemonitor ojeomneo-server -n ojeomneo`

---

## Phase 2: 리뷰맵 Prometheus 엔드포인트 구현

**예상 소요 시간**: 3.5시간 (GitHub Actions + ArgoCD Sync 최적화)
**난이도**: ⭐⭐⭐ (중간)
**리스크**: 중간 (서버 코드 변경 및 배포 필요)

### 2.1 작업 체크리스트

**서버 코드 구현 (reviewmaps-server 레포)**:
- [ ] reviewmaps-server 레포 Feature 브랜치 생성
- [ ] Prometheus 미들웨어 파일 생성 (`internal/middleware/prometheus.go`)
- [ ] 메트릭 초기화 코드 작성
- [ ] `/metrics` 엔드포인트 라우팅 추가
- [ ] 로컬 테스트 (메트릭 엔드포인트 확인: `curl http://localhost:3000/metrics`)
- [ ] GitHub PR 생성 및 main 병합
- [ ] GitHub Actions 완료 대기 (Docker 이미지 빌드 및 infra 레포 자동 반영)

**Helm Chart 수정 (infra 레포)**:
- [ ] infra 레포에 자동 생성된 feature 브랜치 확인
- [ ] `charts/helm/prod/reviewmaps/values.yaml`에서 `serviceMonitor.enabled: true` 설정 추가
- [ ] infra 레포 PR 생성 및 main 병합
- [ ] **ArgoCD 강제 Sync 실행** (kubectl 또는 UI 사용)
- [ ] ServiceMonitor 배포 확인
- [ ] Prometheus Targets 확인
- [ ] 메트릭 수집 검증

### 2.2 구현 대상 파일

**새로 생성할 파일**:

1. `/Users/woohyeon/ggorockee/reviewmaps/server/internal/middleware/prometheus.go`
   - Prometheus 미들웨어 구현
   - 메트릭 정의 (Counter, Histogram, Gauge, Summary)
   - PrometheusHandler 함수 구현

2. `/Users/woohyeon/ggorockee/reviewmaps/server/cmd/api/main.go` (수정)
   - `/metrics` 엔드포인트 추가
   - Prometheus 미들웨어 등록

**수정할 파일**:

3. `charts/helm/prod/reviewmaps/values.yaml`
   - Line 358: `serviceMonitor.enabled: false` → `true`

### 2.3 구현 참고사항

**메트릭 네이밍 규칙**:
- 접두사: `reviewmaps_`
- 예시: `reviewmaps_http_requests_total`

**구현 참고 코드**:
- 오점너 서버의 Prometheus 구현 참조
- 파일: `/Users/woohyeon/woohalabs/ojeomneo/server/internal/middleware/prometheus.go`

**엔드포인트**:
- Path: `/metrics`
- Port: `http` (3000)

### 2.4 테스트 방법

**로컬 테스트**:
- 서버 실행 후 `curl http://localhost:3000/metrics` 실행
- Prometheus 형식 메트릭 출력 확인

**예상 출력 예시**:
```
# HELP reviewmaps_http_requests_total Total number of HTTP requests
# TYPE reviewmaps_http_requests_total counter
reviewmaps_http_requests_total{method="GET",path="/v1/campaigns",status="200"} 42
```

**Docker 이미지 테스트**:
- 빌드: `docker build -t ggorockee/reviewmaps-server:test .`
- 실행: `docker run -p 3000:3000 ggorockee/reviewmaps-server:test`
- 검증: `curl http://localhost:3000/metrics`

### 2.5 배포 프로세스

**Step 1: 서버 코드 배포 (reviewmaps-server 레포)**:
1. reviewmaps-server 레포에서 feature 브랜치 작업
2. PR 생성 및 main 병합
3. GitHub Actions 자동 실행:
   - Docker 이미지 빌드: `ggorockee/reviewmaps-server:YYYYMMDD-commit`
   - Docker Hub 푸시
   - infra 레포에 feature 브랜치 생성 및 이미지 태그 업데이트
   - infra 레포 PR 자동 병합
4. GitHub Actions 완료 대기 (약 5-10분)

**Step 2: Helm Chart 업데이트 (infra 레포)**:
1. infra 레포의 자동 생성된 feature 브랜치 확인
2. 동일 브랜치에서 `charts/helm/prod/reviewmaps/values.yaml` 수정:
   - `serviceMonitor.enabled: true` 추가
3. PR 업데이트 및 main 병합
4. **ArgoCD 강제 Sync**:
   - kubectl: `kubectl patch app reviewmaps -n argocd -p '{"operation":{"sync":{}}}' --type merge`
   - 또는 ArgoCD UI에서 reviewmaps Application 선택 후 Sync 버튼 클릭

**Step 3: 배포 확인**:
1. Pod 재시작 확인: `kubectl get pods -n reviewmaps -w`
2. Pod 로그 확인: `kubectl logs -f deployment/reviewmaps-server -n reviewmaps`
3. ServiceMonitor 배포 확인: `kubectl get servicemonitors -n reviewmaps`

### 2.6 검증 방법

**Phase 1과 동일한 검증 절차**:
- ServiceMonitor 배포 확인
- Prometheus Targets 확인
- 메트릭 수집 확인

**추가 검증**:
- 리뷰맵 Pod 로그 확인 (에러 없음)
- Health check 정상 동작 확인
- 기존 API 기능 정상 동작 확인

### 2.7 롤백 계획

**롤백 시나리오**:
1. 메트릭 수집 실패
2. 서버 장애 발생
3. 성능 저하

**롤백 방법**:
- ArgoCD에서 이전 버전으로 롤백
- `kubectl rollout undo deployment/reviewmaps-server -n reviewmaps`
- values.yaml에서 serviceMonitor.enabled: false

---

## Phase 3: 모니터링 대시보드 구성

**예상 소요 시간**: 2시간
**난이도**: ⭐⭐ (중간)
**리스크**: 낮음 (시각화만)

### 3.1 작업 체크리스트

- [ ] Grafana 접속 확인
- [ ] Prometheus 데이터소스 연결 확인
- [ ] ReviewMaps 대시보드 생성
- [ ] Ojeomneo 대시보드 생성
- [ ] 공통 대시보드 생성 (선택)
- [ ] Alert Rule 설정 (선택)

### 3.2 대시보드 구성 요소

**ReviewMaps 대시보드**:

| 패널 | 메트릭 | 설명 |
|------|--------|------|
| Request Rate | reviewmaps_http_requests_total | 초당 요청 수 |
| Response Time | reviewmaps_http_request_duration_seconds | P50, P95, P99 |
| Error Rate | reviewmaps_http_requests_total (status=~"5..") | 5xx 에러율 |
| Active Connections | reviewmaps_http_active_connections | 현재 활성 연결 |

**Ojeomneo 대시보드**:

| 패널 | 메트릭 | 설명 |
|------|--------|------|
| Request Rate | ojeomneo_http_requests_total | 초당 요청 수 |
| Response Time | ojeomneo_http_request_duration_seconds | P50, P95, P99 |
| Error Rate | ojeomneo_http_requests_total (status=~"5..") | 5xx 에러율 |
| Active Connections | ojeomneo_http_active_connections | 현재 활성 연결 |

### 3.3 PromQL 쿼리 예시

**Request Rate (RPS)**:
```
rate(reviewmaps_http_requests_total[5m])
rate(ojeomneo_http_requests_total[5m])
```

**Response Time (P95)**:
```
histogram_quantile(0.95, rate(reviewmaps_http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.95, rate(ojeomneo_http_request_duration_seconds_bucket[5m]))
```

**Error Rate**:
```
sum(rate(reviewmaps_http_requests_total{status=~"5.."}[5m])) / sum(rate(reviewmaps_http_requests_total[5m]))
sum(rate(ojeomneo_http_requests_total{status=~"5.."}[5m])) / sum(rate(ojeomneo_http_requests_total[5m]))
```

### 3.4 Alert Rule 예시 (선택)

**High Error Rate Alert**:
- 조건: Error Rate > 5% for 5분
- 심각도: Warning
- 알림: Slack, Email

**High Response Time Alert**:
- 조건: P95 Latency > 1초 for 5분
- 심각도: Warning
- 알림: Slack, Email

**Service Down Alert**:
- 조건: up{job="reviewmaps-server"} == 0
- 심각도: Critical
- 알림: Slack, Email, PagerDuty

### 3.5 Grafana 대시보드 저장

**저장 방법**:
- JSON 파일로 export
- Git 저장소에 커밋
- 위치: `charts/helm/prod/kube-prometheus-stack/dashboards/`

**파일명 예시**:
- `reviewmaps-dashboard.json`
- `ojeomneo-dashboard.json`

---

## 검증 체크리스트

### Phase 1 검증

- [ ] ServiceMonitor 리소스 생성 확인
- [ ] Prometheus Targets에 ojeomneo-server 등록 (UP 상태)
- [ ] 메트릭 5개 모두 수집 확인
- [ ] 메트릭 라벨 정상 확인 (method, path, status)
- [ ] Grafana에서 메트릭 조회 가능

### Phase 2 검증

- [ ] Prometheus 미들웨어 코드 구현
- [ ] `/metrics` 엔드포인트 응답 확인
- [ ] Docker 이미지 빌드 성공
- [ ] ServiceMonitor 리소스 생성 확인
- [ ] Prometheus Targets에 reviewmaps-server 등록 (UP 상태)
- [ ] 메트릭 수집 확인
- [ ] 기존 API 기능 정상 동작
- [ ] Pod 로그 에러 없음

### Phase 3 검증

- [ ] Grafana 대시보드 생성 완료
- [ ] 모든 패널 정상 표시
- [ ] PromQL 쿼리 정상 동작
- [ ] Alert Rule 정상 동작 (선택)
- [ ] 대시보드 JSON 파일 Git 커밋

---

## 롤백 계획

### Phase 1 롤백

**상황**: ServiceMonitor 활성화 후 문제 발생

**롤백 절차**:
1. ArgoCD UI에서 이전 Revision 선택
2. Sync 실행
3. 또는 values.yaml 수정 후 재배포

**롤백 명령어**:
- ServiceMonitor 삭제: `kubectl delete servicemonitor ojeomneo-server -n ojeomneo`

**영향도**: 낮음 (메트릭 수집만 중단, 앱 기능 영향 없음)

### Phase 2 롤백

**상황**: Prometheus 엔드포인트 구현 후 서버 장애 발생

**롤백 절차**:
1. ArgoCD에서 이전 이미지 버전으로 롤백
2. 또는 Kubernetes Deployment 롤백 실행
3. values.yaml의 serviceMonitor.enabled: false

**롤백 명령어**:
- Deployment 롤백: `kubectl rollout undo deployment/reviewmaps-server -n reviewmaps`
- 이전 버전 확인: `kubectl rollout history deployment/reviewmaps-server -n reviewmaps`

**영향도**: 중간 (서버 재시작, 일시적 서비스 중단 가능)

### Phase 3 롤백

**상황**: 대시보드 또는 Alert 문제

**롤백 절차**:
1. Grafana에서 대시보드 삭제
2. Alert Rule 비활성화

**영향도**: 없음 (시각화만 영향, 앱 기능 영향 없음)

---

## 타임라인

| Phase | 작업 내용 | 예상 시간 | 누적 시간 | 비고 |
|-------|-----------|-----------|-----------|------|
| Phase 1 | 오점너 ServiceMonitor 활성화 | 15분 | 15분 | ArgoCD 강제 Sync로 시간 단축 |
| Phase 2 | 리뷰맵 Prometheus 엔드포인트 구현 | 3.5시간 | 3시간 45분 | GitHub Actions + ArgoCD Sync |
| Phase 3 | 모니터링 대시보드 구성 | 2시간 | 5시간 45분 | Grafana 설정만 |

**전체 예상 소요 시간**: 약 6시간 (ArgoCD 강제 Sync로 약 1시간 단축)

### 시간 단축 요인

| 항목 | 기존 방식 | 최적화 방식 | 절감 시간 |
|------|-----------|-------------|-----------|
| Phase 1 배포 대기 | 15분 (ArgoCD 자동 감지) | 즉시 (강제 Sync) | 10분 |
| Phase 2 배포 대기 | 30분 (GitHub Actions + ArgoCD) | 20분 (강제 Sync) | 10분 |
| **총 절감 시간** | - | - | **약 20분** |

---

## 참고 자료

### Prometheus 문서
- ServiceMonitor CRD: Prometheus Operator 공식 문서
- Prometheus 메트릭 네이밍: Prometheus Best Practices

### 구현 참고 코드
- 오점너 Prometheus 미들웨어: `/Users/woohyeon/woohalabs/ojeomneo/server/internal/middleware/prometheus.go`
- 오점너 서버 설정: `/Users/woohyeon/woohalabs/ojeomneo/server/internal/module/server.go`

### Helm Chart
- 리뷰맵 ServiceMonitor: `charts/helm/prod/reviewmaps/charts/server/templates/servicemonitor.yaml`
- 오점너 ServiceMonitor: `charts/helm/prod/ojeomneo/charts/server/templates/servicemonitor.yaml`

---

## 승인 체크리스트

- [ ] Phase 1 작업 계획 검토 및 승인
- [ ] Phase 2 작업 계획 검토 및 승인
- [ ] Phase 3 작업 계획 검토 및 승인
- [ ] 롤백 계획 검토 및 승인

**승인자**: _________________
**승인일**: _________________

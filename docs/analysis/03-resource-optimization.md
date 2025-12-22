# 리소스 사용량 및 최적화 분석

**분석 일자**: 2025-12-22
**분석자**: Claude Code (SuperClaude Framework)
**대상**: GKE Autopilot 클러스터 전체 워크로드

---

## 📊 전체 리소스 사용 현황

### 노드 레벨 리소스 사용률

| 노드 | CPU Request | CPU Limit | Memory Request | Memory Limit | 사용률 |
|------|------------|-----------|---------------|-------------|--------|
| gke-...42k0 | 202m | - | 3037Mi | - | CPU 10%, Mem 50% |
| gke-...swm0 | 293m | - | 2964Mi | - | CPU 15%, Mem 49% |

**총계**:
- CPU 사용: 495m / ~4000m (12.4%)
- Memory 사용: 6001Mi / ~12Gi (50%)

### 워크로드별 리소스 사용 상세

| 워크로드 | CPU 사용 | Memory 사용 | 비율 (CPU) | 비율 (Mem) |
|---------|---------|------------|-----------|-----------|
| Monitoring | 111m | 888Mi | 22.4% | 14.8% |
| ArgoCD | 42m | 706Mi | 8.5% | 11.8% |
| Ojeomneo | 41m | 361Mi | 8.3% | 6.0% |
| Istio | 5m | 110Mi | 1.0% | 1.8% |
| ReviewMaps | 10m | 326Mi | 2.0% | 5.4% |
| kube-system | ~80m | ~600Mi | 16.2% | 10.0% |
| 기타 | ~206m | ~3010Mi | 41.6% | 50.2% |

---

## 🔍 상위 리소스 소비 Pod 분석

### CPU 사용량 Top 10

| Pod | CPU | Memory | 네임스페이스 | 용도 |
|-----|-----|--------|------------|------|
| prometheus-...-0 | 90m | 531Mi | monitoring | 메트릭 수집/저장 |
| ojeomneo-redis-master-0 | 30m | 50Mi | ojeomneo | Redis 캐시 |
| argocd-application-controller-0 | 29m | 419Mi | argocd | ArgoCD 컨트롤러 |
| collector-hl96q | 9m | 119Mi | gmp-system | GKE 메트릭 수집 |
| fluentbit-gke-* | 7m | 59Mi | kube-system | 로그 수집 |
| kube-prometheus-stack-grafana | 6m | 278Mi | monitoring | 대시보드 |
| redis (ojeomneo) | 30m | 50Mi | ojeomneo | Redis |
| argocd-repo-server | 3m | 110Mi | argocd | Git 동기화 |
| istiod | 3m | 59Mi | istio-system | Service Mesh |
| metrics-server | 3m | 35Mi | kube-system | 메트릭 수집 |

### Memory 사용량 Top 10

| Pod | CPU | Memory | 네임스페이스 | 용도 |
|-----|-----|--------|------------|------|
| prometheus-...-0 | 90m | 531Mi | monitoring | 메트릭 저장 |
| argocd-application-controller-0 | 29m | 419Mi | argocd | ArgoCD |
| kube-prometheus-stack-grafana | 6m | 278Mi | monitoring | Grafana |
| ojeomneo-admin | 4m | 170Mi | ojeomneo | Django Admin |
| reviewmaps-admin | 3m | 147Mi | reviewmaps | Django Admin |
| collector-hl96q | 9m | 119Mi | gmp-system | GKE 메트릭 |
| argocd-repo-server | 3m | 110Mi | argocd | Git 동기화 |
| reviewmaps-web | 3m | 101Mi | reviewmaps | Next.js |
| ojeomneo-web | 3m | 87Mi | ojeomneo | Next.js |
| reviewmaps-server | 4m | 78Mi | reviewmaps | Django API |

---

## 📈 리소스 효율성 분석

### 1. CPU 효율성

**현황**:
- 전체 노드 CPU: ~4000m (4 cores)
- 사용 중 CPU: 495m
- 활용률: 12.4%
- **평가**: ⚠️ 매우 낮음 (권장: 60-80%)

**원인 분석**:
1. **트래픽 부족**: 현재 서비스 트래픽이 낮은 상태
2. **과도한 리소스 할당**: Request가 실제 필요량보다 높게 설정
3. **GKE Autopilot 특성**: 노드 크기가 자동으로 할당되어 여유 확보

**최적화 방안**:
- 즉각적인 조치 불필요 (여유 확보가 장점)
- 트래픽 증가 시 자동 스케일링으로 대응
- 비용 관점에서 현재 상태 유지 권장

### 2. Memory 효율성

**현황**:
- 전체 노드 Memory: ~12Gi
- 사용 중 Memory: 6001Mi (~6Gi)
- 활용률: 50%
- **평가**: ✅ 적정 수준 (권장: 50-70%)

**최적화 방안**:
- 현재 상태 유지 권장
- Memory Leak 모니터링 강화
- OOM (Out of Memory) 알람 설정

### 3. 스토리지 효율성

**현황**:
- 총 PVC 사용량: 39Gi
- Prometheus: 20Gi (최대 소비)
- Grafana: 5Gi
- Ojeomneo Database: 10Gi
- Redis: 2Gi

**최적화 방안**:
- Prometheus 데이터 보관 기간 검토 (기본 15일)
- Grafana 대시보드 정기 백업 및 정리
- Database 백업 자동화

---

## 💡 애플리케이션별 최적화 제안

### 1. Ojeomneo

#### 현재 리소스 사용

| 컴포넌트 | CPU | Memory | Request (예상) | Limit (예상) |
|---------|-----|--------|--------------|-------------|
| admin | 4m | 170Mi | 50m | 200m |
| server | 4m | 54Mi | 50m | 200m |
| web | 3m | 87Mi | 50m | 200m |
| redis | 30m | 50Mi | 100m | 200m |

#### 최적화 제안

**CPU**:
- admin, server, web: Request 25m → 50m 유지 (여유 확보)
- redis: Request 50m → 100m (현재 사용량 고려)

**Memory**:
- admin: Request 128Mi → 256Mi (현재 170Mi 사용)
- server: Request 64Mi → 128Mi (현재 54Mi 사용)
- web: Request 96Mi → 128Mi (현재 87Mi 사용)
- redis: Request 64Mi → 128Mi (현재 50Mi 사용)

#### HPA 설정 권장

- Target CPU: 70%
- Min Replicas: 2
- Max Replicas: 5

### 2. ReviewMaps

#### 현재 리소스 사용

| 컴포넌트 | CPU | Memory | Request (예상) | Limit (예상) |
|---------|-----|--------|--------------|-------------|
| admin | 3m | 147Mi | 50m | 200m |
| server | 4m | 78Mi | 100m | 500m |
| web | 3m | 101Mi | 50m | 200m |

#### 최적화 제안

**CPU**:
- admin, web: Request 25m → 50m 유지
- server: Request 50m → 100m (현재 설정 유지)

**Memory**:
- admin: Request 128Mi → 256Mi (현재 147Mi 사용)
- server: Request 128Mi → 256Mi (현재 78Mi 사용, 여유 확보)
- web: Request 96Mi → 128Mi (현재 101Mi 사용)

#### HPA 설정 권장

- Target CPU: 70%
- Min Replicas: 2
- Max Replicas: 5

### 3. Monitoring 스택

#### 현재 리소스 사용

| 컴포넌트 | CPU | Memory | 비고 |
|---------|-----|--------|------|
| Prometheus | 90m | 531Mi | 가장 높음 |
| Grafana | 6m | 278Mi | 적정 |
| Alertmanager | 3m | 33Mi | 낮음 |
| OTEL Collector | 1m | 35Mi | 낮음 |

#### 최적화 제안

**Prometheus**:
- 현재 설정 유지 (메트릭 수집량 많음)
- 데이터 보관 기간 검토: `--storage.tsdb.retention.time=15d` (기본값)
- Retention 조정: 7-10일로 단축 고려 (스토리지 절약)

**Grafana**:
- 현재 설정 유지
- 대시보드 정기 정리 및 백업

**Alertmanager**:
- 현재 설정 유지 (효율적 사용)

---

## 🎯 우선순위별 최적화 조치

### Tier 1: 즉시 조치 (High Priority)

#### 1. 고가용성 설정 (비용 증가 예상: ~$5-10/month)

**조치**:
- Ojeomneo, ReviewMaps 모든 Deployment replica를 2개로 증가
- PodDisruptionBudget 설정

**예상 리소스 증가**:
- CPU: +51m (Ojeomneo 41m + ReviewMaps 10m)
- Memory: +687Mi (Ojeomneo 361Mi + ReviewMaps 326Mi)

**예상 비용**:
- GKE Autopilot: vCPU당 $0.04/hour, Memory 1Gi당 $0.004/hour
- 월 비용 증가: 약 $5-10

#### 2. 리소스 Request/Limit 최적화

**조치**:
- 실제 사용량 기반으로 Request 재설정
- Limit은 Request의 2배로 설정 (버스트 대응)

**예상 효과**:
- Pod 스케줄링 효율성 향상
- OOM 발생 위험 감소
- 비용 변화 없음 (GKE Autopilot은 실제 사용량 기준 과금)

### Tier 2: 중기 조치 (Medium Priority)

#### 1. HPA (Horizontal Pod Autoscaler) 설정

**조치**:
- CPU 기반 HPA 설정: Target 70%
- Min 2, Max 5 replicas

**예상 효과**:
- 트래픽 급증 시 자동 스케일링
- 서비스 안정성 향상
- 평시 비용 변화 없음

#### 2. Prometheus 데이터 보관 기간 최적화

**조치**:
- Retention 15d → 10d로 단축
- Remote Write 설정 (장기 보관 필요 시)

**예상 효과**:
- 스토리지 사용량 30% 감소 (20Gi → 14Gi)
- 비용 절감: 약 $1-2/month

### Tier 3: 장기 조치 (Low Priority)

#### 1. 노드 크기 최적화

**현황**:
- GKE Autopilot이 자동으로 노드 크기 관리
- 현재 2개 노드 (각 ~2 cores, ~6Gi)

**조치**:
- 현재 상태 유지 권장
- Autopilot에게 최적화 위임

#### 2. Spot/Preemptible Node 활용 (GKE Autopilot 미지원)

**현황**:
- GKE Autopilot은 Spot Instance 미지원
- Standard GKE로 전환 시에만 가능

**조치**:
- 현재 Autopilot 유지 권장
- 운영 편의성 > 비용 절감

---

## 📊 최적화 후 예상 리소스 사용

### 고가용성 설정 후 (Replica 2배 증가)

| 항목 | 현재 | 최적화 후 | 증가율 |
|------|------|----------|-------|
| 애플리케이션 Pod 수 | 9 | 15 | +67% |
| CPU 사용 | 495m | 597m | +21% |
| Memory 사용 | 6001Mi | 7375Mi | +23% |
| 노드 수 (예상) | 2 | 2-3 | +0-50% |

### 예상 월별 비용

| 항목 | 현재 비용 | 최적화 후 | 증감 |
|------|----------|----------|------|
| GKE Autopilot | $50-70 | $55-80 | +$5-10 |
| Cloud NAT | $35-40 | $35-40 | $0 |
| Cloud Storage | $5-10 | $4-8 | -$1-2 |
| 총합 | $90-125 | $94-128 | +$4-8 |

**ROI (Return on Investment)**:
- 월 비용 증가: $4-8
- 서비스 안정성 향상: 매우 높음
- 다운타임 방지 가치: 서비스 중단 시 매출 손실 대비 저렴

---

## ✅ 리소스 최적화 체크리스트

### 즉시 조치

- [ ] Ojeomneo Deployment replica 2로 증가
- [ ] ReviewMaps Deployment replica 2로 증가
- [ ] PodDisruptionBudget 설정 (minAvailable: 1)
- [ ] 리소스 Request/Limit 재설정

### 중기 조치

- [ ] HPA 설정 (Ojeomneo, ReviewMaps)
- [ ] Prometheus retention 10일로 단축
- [ ] 리소스 사용률 모니터링 대시보드 개선

### 장기 조치

- [ ] Custom Metrics HPA 고려 (RPS, Latency)
- [ ] VPA (Vertical Pod Autoscaler) 검토
- [ ] 리소스 최적화 정기 리뷰 (월 1회)

---

## 📚 관련 문서

- [Kubernetes 클러스터 상태](./01-k8s-cluster-status.md)
- [애플리케이션 상태 점검](./02-application-health.md)
- [모니터링 개선 방안](./04-observability-improvement.md)
- [엔터프라이즈 모니터링 설계](./05-enterprise-monitoring.md)

---

**최종 업데이트**: 2025-12-22
**다음 점검 예정일**: 2025-12-29

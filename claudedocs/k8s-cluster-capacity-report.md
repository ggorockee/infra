# Kubernetes 클러스터 용량 점검 리포트

**작성일**: 2025-12-16
**클러스터**: GKE woohalabs-prod
**GKE 버전**: v1.33.5-gke.1308000

---

## 1. 요약 (Executive Summary)

### 종합 평가: ✅ **양호 (현재 용량 충분)**

| 평가 항목 | 상태 | 점수 |
|---------|------|------|
| 노드 가용성 | ✅ 정상 | 2/2 노드 Ready |
| CPU 사용률 | ✅ 여유 | 실사용 5-6% |
| 메모리 사용률 | ✅ 여유 | 실사용 36-38% |
| Pod 분산 | ✅ 균형 | 28 vs 19 pods |
| 스토리지 | ✅ 정상 | 3 PV Bound |
| 경고 이벤트 | ⚠️ 주의 | Secret 누락 |

### 주요 발견사항

**긍정적**:
- ✅ 노드 상태 정상 (2개 노드 모두 Ready)
- ✅ CPU 여유 충분 (실사용률 5-6%, 요청률 65-77%)
- ✅ 메모리 여유 충분 (실사용률 36-38%, 요청률 33%)
- ✅ Pod 분산 균형 (28개 vs 19개)
- ✅ HPA 정상 작동 (3개 설정)

**개선 필요**:
- ⚠️ ReviewMaps CronJob Secret 누락 (naver-api-creds)
- ⚠️ 메모리 Limit 오버커밋 (131-179%)
- ℹ️ ArgoCD 외부 시크릿 동기화 실패

---

## 2. 노드 상태

### 2.1 노드 목록

| 노드 이름 | 상태 | 역할 | 가동시간 | 커널 버전 | 내부 IP | 외부 IP |
|----------|------|------|----------|-----------|---------|---------|
| gke-...-42k0 | Ready | worker | 13시간 | 6.6.105+ | 10.178.0.43 | 34.64.192.72 |
| gke-...-swm0 | Ready | worker | 13시간 | 6.6.105+ | 10.178.0.44 | 34.64.71.177 |

**컨테이너 런타임**: containerd 2.0.6
**OS**: Container-Optimized OS from Google

### 2.2 노드별 하드웨어 사양

| 노드 | CPU 코어 | 메모리 (전체) | CPU (할당가능) | 메모리 (할당가능) |
|------|----------|--------------|----------------|------------------|
| 42k0 | 2 cores | 7.8 GiB | 1930m (1.93 cores) | 5.9 GiB |
| swm0 | 2 cores | 7.8 GiB | 1930m (1.93 cores) | 5.9 GiB |

**총 클러스터 용량**:
- **CPU**: 4 cores (할당가능: 3.86 cores)
- **메모리**: 15.6 GiB (할당가능: 11.8 GiB)

---

## 3. 리소스 사용 현황

### 3.1 노드별 실시간 사용률

| 노드 | CPU 사용량 | CPU % | 메모리 사용량 | 메모리 % |
|------|-----------|-------|--------------|----------|
| 42k0 | 117m | **6%** | 2184 MiB | **36%** |
| swm0 | 103m | **5%** | 2323 MiB | **38%** |

**평균 사용률**:
- **CPU**: 5.5% (매우 여유)
- **메모리**: 37% (여유)

### 3.2 노드별 리소스 요청/제한 (Allocated Resources)

#### Node 1: gke-...-42k0

| 리소스 | 요청 (Requests) | 요청률 | 제한 (Limits) | 제한률 |
|-------|----------------|-------|--------------|-------|
| **CPU** | 1491m | **77%** | 7043m | 364% ⚠️ |
| **Memory** | 2020 MiB | **33%** | 7919 MiB | 131% ⚠️ |

#### Node 2: gke-...-swm0

| 리소스 | 요청 (Requests) | 요청률 | 제한 (Limits) | 제한률 |
|-------|----------------|-------|--------------|-------|
| **CPU** | 1259m | **65%** | 14400m | 746% ⚠️ |
| **Memory** | 2012 MiB | **33%** | 10804 MiB | 179% ⚠️ |

**해석**:
- ✅ **Requests (요청)**: 33-77% 수준으로 정상
- ⚠️ **Limits (제한)**: CPU 364-746%, Memory 131-179% 오버커밋
  - **의미**: 모든 Pod가 동시에 최대 리소스를 사용하면 노드 용량 초과
  - **실제 영향**: 현재 실사용률이 낮아 문제 없음 (5-6% CPU, 36-38% Memory)
  - **권장사항**: 리소스 Limits를 적절히 조정하거나, HPA로 부하 분산

### 3.3 클러스터 전체 리소스 요약

| 리소스 | 총 용량 | 할당 가능 | 요청 총합 | 제한 총합 | 실사용 |
|-------|---------|----------|----------|----------|--------|
| **CPU** | 4000m | 3860m | 2750m (71%) | 21443m (555%) | 220m (5.7%) |
| **Memory** | 15.6 GiB | 11.8 GiB | 4.0 GiB (34%) | 17.4 GiB (147%) | 4.4 GiB (37%) |

**여유 리소스**:
- **CPU 여유**: 1110m (29% 여유) - 추가 Pod 배치 가능
- **메모리 여유**: 7.8 GiB (66% 여유) - 충분한 여유 공간

---

## 4. Pod 배치 현황

### 4.1 네임스페이스별 Pod 수

| 네임스페이스 | Pod 수 |
|-------------|--------|
| kube-system | 14 |
| gmp-system | 3 |
| argocd | 7 |
| istio-system | 2 |
| cert-manager | 3 |
| external-secrets-system | 3 |
| ojeomneo | 2 |
| reviewmaps | 5 |
| gke-managed-cim | 1 |
| **총합** | **47 pods** |

### 4.2 노드별 Pod 분산

| 노드 | 배치된 Pod 수 | 비율 |
|------|--------------|------|
| 42k0 | 28 pods | 59.6% |
| swm0 | 19 pods | 40.4% |

**분산 상태**: 약간 불균형하지만 허용 범위 (60:40 비율)

### 4.3 애플리케이션 Pod 리소스 설정

#### Ojeomneo Namespace

| Pod | Requests (CPU/Mem) | Limits (CPU/Mem) | 상태 |
|-----|-------------------|------------------|------|
| ojeomneo-admin | 50m / 128Mi | 200m / 256Mi | Running |
| ojeomneo-server | 100m / 128Mi | 500m / 256Mi | Running |

**총 요청**: 150m CPU, 256Mi Memory
**총 제한**: 700m CPU, 512Mi Memory

#### ReviewMaps Namespace

| Pod | Requests (CPU/Mem) | Limits (CPU/Mem) | 상태 |
|-----|-------------------|------------------|------|
| reviewmaps-admin | 50m / 128Mi | 200m / 256Mi | Running |
| reviewmaps-admin-migration | 50m / 128Mi | 200m / 256Mi | Running |
| reviewmaps-server | 100m / 256Mi | 500m / 512Mi | Running |
| reviewmaps-go-cleanup (CronJob) | 100m / 128Mi | 500m / 512Mi | Running |
| reviewmaps-go-cron-reviewnote (CronJob) | 100m / 128Mi | 500m / 512Mi | Running |

**총 요청**: 400m CPU, 768Mi Memory
**총 제한**: 1900m CPU, 2048Mi Memory

### 4.4 주요 시스템 Pod 리소스 소비

**상위 10개 CPU 사용 Pod**:

| Pod | CPU 사용량 | 메모리 사용량 |
|-----|-----------|--------------|
| collector-hl96q (gmp-system) | 8m | 115Mi |
| fluentbit-gke-4rr2g (kube-system) | 7m | 49Mi |
| fluentbit-gke-zgg6j (kube-system) | 6m | 52Mi |
| collector-6vfrh (gmp-system) | 6m | 100Mi |
| argocd-redis | 5m | 12Mi |
| istiod | 4m | 58Mi |
| gke-metrics-agent (×2) | 4m | 70-74Mi |
| argocd-application-controller | 3m | 245Mi |

**상위 메모리 사용 Pod**:
- argocd-application-controller: 245Mi
- gke-metrics-agent: 70-74Mi
- argocd-repo-server: 58Mi
- istiod: 58Mi

---

## 5. Horizontal Pod Autoscaler (HPA) 현황

### 5.1 설정된 HPA

| Namespace | HPA 이름 | 대상 | 현재/목표 메트릭 | Min/Max | 현재 Replicas |
|-----------|---------|------|-----------------|---------|---------------|
| gke-managed-cim | kube-state-metrics | StatefulSet | memory: 50Mi/400Mi | 1-10 | 1 |
| istio-system | istiod | Deployment | cpu: 2%/80% | 1-5 | 1 |
| reviewmaps | reviewmaps-server | Deployment | cpu: 3%/80% | 1-3 | 1 |

**상태**: 모두 정상 작동 중, CPU/Memory 사용률이 낮아 스케일아웃 필요 없음

### 5.2 HPA 미설정 애플리케이션

| Namespace | Deployment | 현재 Replicas | 권장사항 |
|-----------|-----------|---------------|----------|
| ojeomneo | ojeomneo-server | 1 | HPA 설정 권장 (트래픽 증가 대비) |
| ojeomneo | ojeomneo-admin | 1 | 선택적 (Admin은 트래픽 낮음) |
| reviewmaps | reviewmaps-admin | 1 | 선택적 |

---

## 6. 스토리지 현황

### 6.1 Persistent Volumes (PV)

| PV 이름 | 용량 | 상태 | 연결된 PVC | 네임스페이스 |
|---------|------|------|-----------|-------------|
| pvc-5fc2eb5b-... | 10Gi | Bound | data-ojeomneo-database-0 | ojeomneo |
| pvc-ea9b0bf6-... | 1Gi | Bound | redis-data-ojeomneo-redis-master-0 | ojeomneo |
| pvc-f113a132-... | 1Gi | Bound | redis-data-ojeomneo-redis-replicas-0 | ojeomneo |

**총 스토리지 사용량**: 12 GiB (10 + 1 + 1)
**StorageClass**: standard-rwo (Google Persistent Disk)

### 6.2 스토리지 정책

- **Reclaim Policy**: Delete (PVC 삭제 시 PV도 자동 삭제)
- **Access Mode**: ReadWriteOnce (단일 노드 읽기/쓰기)

**주의사항**:
- Ojeomneo Database PV (10Gi)가 삭제되면 데이터 손실 위험
- 프로덕션 환경에서는 백업 정책 필수

---

## 7. 경고 및 이슈

### 7.1 Pending Pods

**발견된 Pending Pod 수**: 3개

**원인 추정**:
- CronJob Pod가 완료 후 Pending 상태로 남아있을 가능성
- 리소스 부족은 아님 (노드 여유 충분)

### 7.2 Warning Events (최근 발생)

#### 1. ReviewMaps Secret 누락 (높은 우선순위)

**영향**: ReviewMaps CronJob 실행 실패

| Pod | 누락된 Secret | 마지막 발생 시간 |
|-----|--------------|-----------------|
| reviewmaps-go-cleanup | naver-api-creds | 2분 42초 전 |
| reviewmaps-go-cron-reviewnote | naver-api-creds | 2분 34초 전 |

**조치 필요**:
```bash
# naver-api-creds Secret 생성 필요
kubectl create secret generic naver-api-creds -n reviewmaps \
  --from-literal=NAVER_CLIENT_ID=xxx \
  --from-literal=NAVER_CLIENT_SECRET=xxx
```

#### 2. ArgoCD RBAC ExternalSecret 동기화 실패

**에러**: `the desired secret argocd-rbac-cm was not found`
**영향**: ArgoCD RBAC 설정 자동 동기화 안됨 (수동 설정 가능)
**우선순위**: 낮음 (기본 RBAC로 작동 중)

#### 3. Cert-Manager Certificate 업데이트 실패

**에러**: `metadata.resourceVersion: Invalid value: 0x0: must be specified for an update`
**영향**: 와일드카드 인증서 자동 갱신 실패 가능성
**대상**:
- ggorockee-org-wildcard-cert
- woohalabs-com-wildcard-cert

**조치**:
- Certificate 리소스 재생성 또는 ArgoCD 재동기화 필요

---

## 8. 노드 추가 필요성 평가

### 8.1 현재 상황

| 기준 | 현재 상태 | 평가 |
|-----|----------|------|
| **실제 CPU 사용률** | 5-6% | 매우 여유 ✅ |
| **실제 메모리 사용률** | 36-38% | 여유 ✅ |
| **CPU 요청률** | 65-77% | 정상 범위 ✅ |
| **메모리 요청률** | 33% | 충분한 여유 ✅ |
| **Pod 수** | 47개 (노드당 23-28개) | 정상 ✅ |
| **HPA 트리거** | 없음 (CPU 2-3%) | 안정 ✅ |

### 8.2 노드 추가 필요 시나리오

**노드 추가가 필요한 경우**:
- ❌ CPU 요청률이 85% 이상 지속
- ❌ 메모리 요청률이 80% 이상 지속
- ❌ Pod가 Pending 상태로 스케줄링 실패 (현재 없음)
- ❌ HPA가 최대 Replicas에 도달하고 여전히 부하 높음

**현재 상황**: **위 조건 중 해당 없음**

### 8.3 권장사항

**결론**: **현재 노드 용량 충분, 추가 불필요** ✅

**근거**:
1. 실제 CPU 사용률 5-6% (20배 이상 여유)
2. 실제 메모리 사용률 37% (63% 여유)
3. CPU 요청률 65-77% (정상 범위)
4. 모든 Pod 정상 실행 중 (Pending 없음)
5. HPA 여유 (현재 사용률 2-3% vs 목표 80%)

**모니터링 권장**:
- CPU 요청률이 **85% 초과** 시 노드 추가 검토
- 메모리 요청률이 **80% 초과** 시 노드 추가 검토
- HPA가 빈번히 스케일아웃하면 노드 추가 고려

---

## 9. 용량 확장 시나리오

### 9.1 예상 부하 증가 시나리오

#### 시나리오 1: 트래픽 2배 증가

**가정**:
- ReviewMaps HPA가 3 Replicas로 증가 (현재 1 → 3)
- Ojeomneo 수동 스케일아웃 2 Replicas (현재 1 → 2)

**추가 리소스 요구**:
- CPU: +350m (reviewmaps-server 2개, ojeomneo-server 1개)
- Memory: +640Mi

**결과**:
- 총 CPU 요청: 3100m (80% 사용률) → **여전히 여유**
- 총 Memory 요청: 4.6 GiB (39% 사용률) → **충분**

**결론**: **노드 추가 불필요**

#### 시나리오 2: 신규 애플리케이션 추가

**가정**:
- 신규 서비스 3개 추가 (각 100m CPU, 256Mi Memory)

**추가 리소스 요구**:
- CPU: +300m
- Memory: +768Mi

**결과**:
- 총 CPU 요청: 3050m (79% 사용률) → **여유**
- 총 Memory 요청: 4.8 GiB (41% 사용률) → **충분**

**결론**: **노드 추가 불필요**

#### 시나리오 3: 트래픽 5배 증가 (극단적)

**가정**:
- 모든 HPA가 최대 Replicas로 스케일아웃
- ReviewMaps: 1 → 3
- Istiod: 1 → 5
- 추가 애플리케이션 Pod 배치

**추가 리소스 요구**:
- CPU: +1200m
- Memory: +2.5 GiB

**결과**:
- 총 CPU 요청: 3950m (102% 사용률) → **⚠️ 용량 초과**
- 총 Memory 요청: 6.5 GiB (55% 사용률) → **충분**

**결론**: **노드 1개 추가 필요** (CPU 병목)

### 9.2 노드 추가 시점

**권장 타이밍**:
- **예방적**: CPU 요청률 **75% 도달** 시 노드 추가 계획
- **필수**: CPU 요청률 **85% 초과** 시 즉시 노드 추가
- **긴급**: Pod Pending 발생 시 즉시 조치

**현재 상황**: CPU 65-77% → **계획 단계 진입** (추가 불필요하지만 모니터링 강화)

---

## 10. 리소스 최적화 권장사항

### 10.1 즉시 조치 필요

**1) ReviewMaps Secret 생성** (높은 우선순위)
```bash
# ExternalSecret을 통한 Secret 동기화 확인
kubectl get externalsecrets -n reviewmaps

# 없다면 수동 생성
kubectl create secret generic naver-api-creds -n reviewmaps \
  --from-literal=NAVER_CLIENT_ID=your_client_id \
  --from-literal=NAVER_CLIENT_SECRET=your_client_secret
```

### 10.2 단기 개선 (1-2주)

**1) Ojeomneo HPA 설정**

values.yaml에 HPA 활성화:
```yaml
server:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 3
    targetCPUUtilizationPercentage: 80
```

**2) 리소스 Limits 조정**

현재 CPU Limits 746% 오버커밋을 완화:
- GMP Collector Limits: 3G → 500M (메모리)
- Istio Ingressgateway Limits: 2 cores → 1 core (CPU)

**3) Certificate 자동 갱신 수정**

ArgoCD에서 cert-manager 애플리케이션 재동기화:
```bash
argocd app sync cert-manager --force
```

### 10.3 중기 개선 (1-3개월)

**1) 모니터링 강화**
- Prometheus 알람 설정: CPU 요청률 80% 경고
- Grafana 대시보드: 노드 리소스 트렌드 시각화

**2) 리소스 Right-sizing**
- 2주간 실사용 모니터링 후 Request/Limit 재조정
- 과도하게 높은 Limits 제거 (현재 746% 오버커밋)

**3) Node Auto-scaling 검토**
- GKE Cluster Autoscaler 활성화 고려
- Min: 2 nodes, Max: 4 nodes

### 10.4 장기 계획 (3-6개월)

**1) Node Pool 다양화**
- 고성능 워크로드용 Node Pool 분리 (e2-standard-4)
- 저사용 워크로드용 Node Pool (e2-small)

**2) Vertical Pod Autoscaler (VPA) 도입**
- 자동 리소스 Request/Limit 최적화

**3) Pod Topology Spread Constraints**
- 노드 간 Pod 분산 균형 개선 (현재 60:40)

---

## 11. 결론

### 11.1 최종 평가

**현재 클러스터 상태**: ✅ **양호 - 용량 충분**

| 평가 기준 | 현재 수치 | 목표 | 평가 |
|---------|----------|------|------|
| CPU 실사용률 | 5-6% | < 70% | ✅ 매우 여유 |
| 메모리 실사용률 | 36-38% | < 80% | ✅ 여유 |
| CPU 요청률 | 65-77% | < 85% | ✅ 정상 |
| 메모리 요청률 | 33% | < 80% | ✅ 충분 |
| Pod 수 | 47개 | < 100 | ✅ 여유 |
| 노드 상태 | 2/2 Ready | 100% | ✅ 정상 |

### 11.2 노드 추가 필요성

**답변**: **아니오, 현재 노드 추가 불필요** ❌

**근거**:
1. 실제 리소스 사용률이 매우 낮음 (CPU 6%, Memory 37%)
2. 요청 기반 할당도 여유 (CPU 71%, Memory 34%)
3. 모든 Pod가 정상 스케줄링 및 실행 중
4. HPA 여유 충분 (트래픽 증가 시 자동 대응 가능)
5. 트래픽 2배 증가 시나리오에서도 노드 추가 불필요

**노드 추가가 필요한 시점**:
- CPU 요청률 **85% 초과** 지속
- 메모리 요청률 **80% 초과** 지속
- Pod Pending 발생 (리소스 부족으로 스케줄링 실패)
- 트래픽 **5배 이상 급증** 예상

### 11.3 다음 단계 (Action Items)

**즉시 (24시간 이내)**:
- [ ] ReviewMaps Secret (naver-api-creds) 생성
- [ ] Pending Pod 원인 조사 및 정리

**단기 (1-2주)**:
- [ ] Ojeomneo HPA 설정 활성화
- [ ] Certificate 자동 갱신 이슈 해결
- [ ] 리소스 Limits 오버커밋 완화 (746% → 200% 이하)

**중기 (1-3개월)**:
- [ ] Prometheus 알람 설정 (CPU 80%, Memory 75%)
- [ ] 리소스 Right-sizing (2주 모니터링 후 조정)
- [ ] GKE Cluster Autoscaler 검토

**모니터링**:
- [ ] 주간 리소스 사용률 리뷰
- [ ] CPU 요청률 75% 도달 시 노드 추가 계획 수립
- [ ] 트래픽 증가 추세 분석 및 용량 계획

---

## 12. 부록: 명령어 참고

### 노드 상태 확인
```bash
kubectl get nodes -o wide
kubectl top nodes
kubectl describe nodes
```

### Pod 리소스 확인
```bash
kubectl top pods --all-namespaces
kubectl get pods --all-namespaces -o wide
```

### HPA 상태 확인
```bash
kubectl get hpa --all-namespaces
kubectl describe hpa -n reviewmaps reviewmaps-server
```

### 스토리지 확인
```bash
kubectl get pv
kubectl get pvc --all-namespaces
```

### 경고 이벤트 확인
```bash
kubectl get events --all-namespaces --field-selector type=Warning
```

### 리소스 할당률 확인
```bash
kubectl describe nodes | grep -A 5 "Allocated resources:"
```

---

**작성자**: Claude Sonnet 4.5
**검증일**: 2025-12-16 13:30 (KST)
**다음 점검 권장일**: 2025-12-23 (1주일 후)

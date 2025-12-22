# Logging Stack Evolution Plan: Loki → EFK

**작성일**: 2025-12-22
**작성자**: DevOps Team
**상태**: Planning

**프로젝트 개요**: 중앙 집중식 로깅 시스템을 단계적으로 구축하는 계획입니다. 현재 로깅 시스템이 없는 상태에서 Loki를 먼저 설치하여 즉시 사용 가능한 환경을 구축하고, 이후 EFK (Elasticsearch + Fluentd + Kibana) 스택으로 전환하여 고급 분석 기능을 확보합니다.

---

## 개요

본 계획은 **2단계 접근법**을 통해 안전하고 효율적인 로깅 시스템 구축을 목표로 합니다:

- **1단계 (Loki)**: 경량 로깅 시스템으로 빠르게 시작 (1-2주)
- **2단계 (EFK)**: 엔터프라이즈급 검색 및 분석 환경으로 전환 (3-4주)

### 전략적 접근법

**왜 Loki를 먼저 설치하는가?**
- ✅ **빠른 배포**: Loki는 EFK 대비 리소스 요구사항이 낮고 설치가 간단
- ✅ **즉시 가용**: 로깅 시스템을 빠르게 구축하여 애플리케이션 디버깅 시작
- ✅ **학습 곡선**: Loki 운영 경험을 통해 로깅 시스템 이해도 향상
- ✅ **비용 효율**: 초기 단계에서 저렴한 비용으로 시작

**왜 EFK로 전환하는가?**
- 🎯 **검색 성능 향상**: Elasticsearch의 강력한 전문 검색 및 집계 기능
- 🎯 **고급 분석**: Kibana의 시각화 및 대시보드 기능 활용
- 🎯 **통합 관리**: 로그, 메트릭, APM 통합 분석 환경 구축
- 🎯 **엔터프라이즈 기능**: 알림, 머신러닝, 이상 탐지 등

### 핵심 목표

1. **중앙 집중식 로그 수집**: 모든 애플리케이션 로그를 단일 시스템으로 수집
2. **단계적 전환**: Loki로 시작하여 EFK로 전환함으로써 리스크 최소화
3. **데이터 안전성**: Retain StorageClass 정책으로 데이터 보존 보장
4. **무중단 전환**: 병행 운영 기간을 통한 안정적 전환
5. **롤백 가능성**: 각 단계별 복구 계획 수립

---

## 현재 상태 (Phase 0: 미구축)

### 로깅 시스템 현황

**현재 상태**: 중앙 집중식 로깅 시스템 **미구축**

| 항목 | 현재 상태 | 제약사항 |
|------|----------|---------|
| **로그 수집** | 각 Pod의 stdout/stderr | Pod 재시작 시 로그 유실 |
| **로그 검색** | `kubectl logs` 명령 | Pod별 개별 조회만 가능 |
| **로그 보존** | Pod 생명주기에 의존 | Pod 삭제 시 영구 손실 |
| **로그 분석** | 미지원 | 집계, 통계, 시각화 불가 |
| **장애 대응** | 수동 확인 필요 | 여러 Pod 로그를 개별 조회 |

**구축 필요성**: 애플리케이션 디버깅, 장애 대응, 성능 분석을 위한 통합 로깅 시스템 구축이 시급함

### 클러스터 환경

| 항목 | 설정 | 비고 |
|------|------|------|
| **Platform** | GKE (Google Kubernetes Engine) | asia-northeast3-a |
| **Kubernetes** | v1.33.5 | 최신 버전 |
| **Nodes** | 2 nodes (e2-standard-2) | 2 vCPU, 8GB RAM per node |
| **Namespace** | ojeomneo, reviewmaps 등 | 다수 애플리케이션 운영 중 |

### StorageClass 현황

GKE 클러스터에서 사용 가능한 StorageClass 목록:

| 이름 | Provisioner | reclaimPolicy | Default | 특징 |
|------|-------------|--------------|---------|------|
| **gcp-standard-rwo-retain** | pd.csi.storage.gke.io | **Retain** ✅ | ✅ Primary | **로깅용 권장** |
| standard-rwo | pd.csi.storage.gke.io | Delete | ✅ Secondary | 일반 워크로드용 |
| premium-rwo | pd.csi.storage.gke.io | Delete | ❌ | SSD 고성능 |
| standard | kubernetes.io/gce-pd | Delete | ❌ | 레거시 (비권장) |

**로깅 시스템 선택**: `gcp-standard-rwo-retain`

선택 이유:
- **데이터 안전성**: Retain 정책으로 PVC 삭제 시에도 데이터 보존
- **성능 최적화**: WaitForFirstConsumer로 노드와 동일 Zone에 PV 생성
- **전환 안정성**: Loki → EFK 전환 중 데이터 보존 보장

---

## 목표 상태

### 1단계 목표: Loki Stack

| 컴포넌트 | 설정 | 용도 |
|---------|------|------|
| **Loki** | SingleBinary 모드, 1 replica | 로그 저장 및 쿼리 |
| **Fluent Bit** | DaemonSet | 각 노드에서 로그 수집 |
| **Storage** | gcp-standard-rwo-retain (30Gi 전체) | 소규모 앱 로그 저장 |
| **보존 기간** | 90일 (3개월) | GKE 클러스터 교체 주기에 맞춤 |

**Loki 리소스 예상**:
- CPU: 500m
- Memory: 1Gi
- Storage: 30Gi

### 2단계 목표: EFK Stack

| 컴포넌트 | 설정 | 용도 |
|---------|------|------|
| **Elasticsearch** | StatefulSet (3 replicas) | 로그 저장 및 검색 |
| **Fluentd** | DaemonSet | 로그 수집 및 전송 |
| **Kibana** | Deployment (2 replicas) | 시각화 및 대시보드 |
| **Storage** | gcp-standard-rwo-retain (30Gi 전체) | 소규모 앱 규모에 맞춤 |

**EFK 리소스 예상**:
- Elasticsearch: 2 cores, 4Gi × 3 nodes
- Fluentd: 200m, 512Mi
- Kibana: 500m, 1Gi

---

## 로깅 시스템 구축 전략

### 전체 로드맵 (6주 계획)

| Phase | 기간 | 주요 작업 | 상태 | 롤백 시간 |
|-------|------|----------|------|----------|
| **Phase 1** | 1주 | Loki + Fluent Bit 설치 | 📋 계획 중 | 즉시 |
| **Phase 2** | 1주 | Loki 운영 및 안정화 | ⏳ 대기 | 즉시 |
| **Phase 3** | 2주 | EFK 배포 + 병행 운영 | ⏳ 대기 | 5분 |
| **Phase 4** | 1주 | EFK 전환 + Loki 제거 | ⏳ 대기 | 30분 |
| **Phase 5** | 지속 | EFK 최적화 및 튜닝 | ⏳ 대기 | - |

**실행 원칙**:
1. **빠른 시작**: Loki를 1주 내 배포하여 즉시 로깅 가능
2. **점진적 전환**: 병행 운영으로 리스크 최소화
3. **데이터 보존**: Retain StorageClass로 안전성 확보
4. **롤백 준비**: 각 Phase별 명확한 복구 절차 수립

---

### Phase 1: Loki 설치 및 초기 구축 (1주)

**목표**: 중앙 집중식 로깅 시스템 빠르게 구축

#### 1.1 Loki Helm Chart 배포

**Loki 설정**:
- Chart: `grafana/loki 6.46.0` (App Version: 3.5.7)
  - 현재 `kube-prometheus-stack 68.5.0` (Grafana 8.8.*)과 호환 검증됨
  - 안정성 우선 버전 (최신: 6.49.0/3.6.3도 사용 가능)
- 모드: SingleBinary (간단한 배포)
- Storage: gcp-standard-rwo-retain (전체 30Gi, 노드별 할당 아님)
- 보존 기간: 90일 (3개월)

**주요 설정**:
- 기존 values.yaml 재사용
- storageClassName 확인: `gcp-standard-rwo-retain` (자동 적용)
- 네임스페이스: `logging` (신규 생성)

#### 1.2 Fluent Bit 배포

**Fluent Bit 설정**:
- Chart: `fluent/fluent-bit`
- DaemonSet: 모든 노드에 배포
- Output: Loki
- 필터: Kubernetes 메타데이터 추가

#### 1.3 검증 및 테스트

**상태 확인**:
```bash
kubectl get pods -n logging
kubectl get pvc -n logging
```

**기능 검증**:
- [ ] Loki Pod Running 상태 (1/1 Ready)
- [ ] Fluent Bit DaemonSet 모든 노드 배포 (2/2 Ready)
- [ ] 로그 수집 확인 (LogQL 쿼리: `{namespace="ojeomneo"}`)
- [ ] PVC 바인딩 확인 (Bound 상태, gcp-standard-rwo-retain)
- [ ] 로그 보존 확인 (최소 1일치 로그 축적)

---

### Phase 2: Loki 안정화 및 운영 (1주)

**목표**: Loki 운영 경험 축적 및 로깅 시스템 안정화

#### 2.1 Grafana 연동

**Grafana Data Source 추가**:
- Loki를 Grafana Data Source로 추가
- Explore 기능으로 로그 검색 및 분석
- 기본 대시보드 구축

#### 2.2 로그 필터링 최적화

**Fluent Bit 필터 조정**:
- 불필요한 로그 제외 (kube-system 등)
- 로그 레벨 필터링 (ERROR, WARN, INFO)
- 애플리케이션별 라벨 추가

#### 2.3 성능 모니터링

**확인 항목**:
- Loki CPU/Memory 사용률
- 로그 수집 지연 시간
- 디스크 사용량 증가 추이
- LogQL 쿼리 응답 시간

---

### Phase 3: EFK 준비 및 병행 운영 (2주)

**목표**: EFK Stack 배포 및 Loki와 병행 운영으로 안정성 검증

#### 3.1 EFK Stack 배포

**Elasticsearch 배포**:
- Chart: `elastic/elasticsearch`
- StatefulSet: 3 replicas
- Storage: gcp-standard-rwo-retain (전체 30Gi, 소규모 앱 기준)
  - 각 replica당 약 10Gi 할당
- JVM Heap: 1Gi (소규모 환경에 맞춤)

**Fluentd 배포**:
- Chart: `fluent/fluentd`
- DaemonSet
- Output: Elasticsearch

**Kibana 배포**:
- Chart: `elastic/kibana`
- Deployment: 2 replicas
- Istio VirtualService 연동

#### 3.2 이중 수집 (Dual Shipping)

**Fluent Bit 설정 변경**:
- Output 1: Loki (기존 유지)
- Output 2: Fluentd → Elasticsearch (신규 추가)

**장점**:
- Loki 로그 계속 사용 가능
- EFK 안정성 검증 기간 확보
- 문제 발생 시 즉시 롤백

#### 3.3 EFK 검증

**테스트 항목**:
- Elasticsearch 클러스터 상태 확인
- Kibana 로그 검색 테스트
- 로그 수집률 비교 (Loki vs Elasticsearch)
- 검색 성능 비교
- 대시보드 구축

---

### Phase 4: EFK 전환 및 Loki 제거 (1주)

**목표**: EFK로 완전 전환 및 Loki 정리

#### 4.1 트래픽 전환

**Fluent Bit Output 변경**:
- Output 1 비활성화 (Loki)
- Output 2만 활성화 (Fluentd → Elasticsearch)

**모니터링 강화**:
- 전환 후 1시간: 5분마다 확인
- 전환 후 24시간: 1시간마다 확인

#### 4.2 Loki 데이터 보존 (Retain 정책 활용)

**Loki PVC 처리**:

**권장 방법**: PVC 유지 (90일)
- Loki Pod만 삭제
- PVC는 90일 동안 유지 (Retain 정책으로 자동 보존, GKE 클러스터 교체 주기)
- 문제 발생 시 Loki 재배포하여 기존 PVC 재사용

**90일 후**:
- 문제 없으면 PVC 삭제
- PV는 Released 상태로 보존
- 완전 검증 후 PV 수동 삭제

#### 4.3 Loki Stack 제거

**제거 순서**:
1. ✅ Loki Deployment 삭제
2. ✅ Loki Service 삭제
3. ⏳ Loki PVC 90일 유지 (GKE 클러스터 교체 주기)
4. ✅ Loki Helm Release 삭제
5. ✅ ArgoCD Application 정리

---

### Phase 5: EFK 최적화 (진행 중)

**목표**: EFK Stack 성능 최적화 및 고급 기능 활용

#### 5.1 Index Lifecycle Management (ILM)

**ILM 정책**:
- Hot (0-7일): 빠른 검색
- Warm (8-30일): Read-only, 압축
- Cold (31-60일): 아카이브
- Delete (60일 이상): 삭제

#### 5.2 Kibana 대시보드 구축

**기본 대시보드**:
- 애플리케이션별 로그 현황
- 에러 로그 집계 (ERROR, WARN)
- 응답 시간 분석
- 트래픽 추이

**알림 설정**:
- 에러 급증 알림
- 응답 시간 임계값 초과
- Elasticsearch 클러스터 상태 알림

#### 5.3 성능 튜닝

**Elasticsearch 최적화**:
- Shard 크기 최적화
- Replica 수 조정
- Refresh interval 조정
- JVM Heap 튜닝

---

## StorageClass Retain 정책 활용 전략

### Retain 정책의 장점

**gcp-standard-rwo-retain 사용 시**:
- ✅ PVC 삭제 시 PV가 Released 상태로 보존됨
- ✅ 데이터가 자동 삭제되지 않음
- ✅ 필요 시 PV 재사용 가능

### 데이터 보호 시나리오

#### 시나리오 1: Loki 재배포 필요 시

**문제**: Loki Pod가 문제가 생겨 삭제했는데 데이터 보존 필요

**해결**: Retain 정책 덕분에 간단함
1. Loki Helm Chart 재배포
2. 기존 PVC가 그대로 있으므로 자동 바인딩
3. 데이터 손실 없이 즉시 사용 가능

#### 시나리오 2: Loki → EFK 전환 실패 시 롤백

**문제**: EFK 전환 후 문제 발생, Loki로 롤백 필요

**해결**: Retain 정책으로 안전하게 롤백
1. Loki PVC를 90일간 유지해둠 (GKE 클러스터 교체 주기)
2. EFK 문제 발생 시 Loki 재배포
3. 기존 PVC 자동 바인딩
4. 전환 전 로그까지 모두 보존됨

#### 시나리오 3: PVC 실수 삭제

**문제**: 실수로 Loki PVC 삭제

**해결**: Retain 정책으로 복구 가능
1. PVC 삭제해도 PV는 Released 상태로 보존
2. 새 PVC 생성 후 기존 PV와 수동 바인딩
3. 데이터 복구 완료

### Delete 정책과 비교

| 상황 | Retain 정책 | Delete 정책 |
|------|------------|------------|
| PVC 삭제 | PV 보존 (Released) | PV 즉시 삭제 |
| 데이터 복구 | 가능 (PV 재바인딩) | 불가능 (영구 손실) |
| 롤백 | 안전 (기존 데이터 사용) | 불가능 (데이터 없음) |
| 관리 | 수동 PV 정리 필요 | 자동 정리 |
| 비용 | PV 보관 기간 동안 과금 | 즉시 과금 중지 |

**권장**: 로깅 시스템은 데이터 안전성이 중요하므로 **Retain 정책 사용**

---

## 롤백 계획

### 롤백 조건 (Rollback Triggers)

다음 상황 발생 시 즉시 롤백을 실행합니다:

| 조건 | 임계값 | 확인 방법 |
|------|--------|----------|
| **로그 수집률** | < 95% | Fluent Bit 메트릭 확인 |
| **클러스터 상태** | RED 상태 지속 | Elasticsearch cluster health |
| **검색 응답 시간** | > 5초 | Kibana 쿼리 응답 시간 |
| **디스크 사용률** | > 90% | PVC 사용량 모니터링 |
| **비용 초과** | 예산 150% 초과 | GCP Billing 확인 |

### Rollback 절차

#### Phase 3 중 롤백 (Dual Shipping 중)

**가장 간단한 롤백**:
1. Fluent Bit Output에서 Elasticsearch 비활성화
2. Loki Output만 활성화
3. EFK Stack 제거 (optional)

**소요 시간**: 5분
**데이터 손실**: 없음

#### Phase 4 이후 롤백 (Loki 제거 후)

**Loki 재배포**:
1. Loki Helm Chart 재배포
2. 기존 Loki PVC 재사용 (Retain으로 보존됨)
3. Fluent Bit Output을 Loki로 전환
4. EFK Stack 중단

**소요 시간**: 30분
**데이터 손실**: Loki 중단 기간의 로그만 (EFK에는 있음)

---

## 체크리스트

### Phase 1: Loki 설치 (1주차)

**준비 작업**:
- [ ] `logging` 네임스페이스 생성: `kubectl create ns logging`
- [ ] Loki Helm 저장소 추가: `helm repo add grafana https://grafana.github.io/helm-charts`
- [ ] Fluent Bit Helm 저장소 추가: `helm repo add fluent https://fluent.github.io/helm-charts`

**배포 작업**:
- [ ] Loki Helm Chart 배포 (values.yaml 적용)
- [ ] Fluent Bit DaemonSet 배포
- [ ] ArgoCD Application 생성 (GitOps 관리)

**검증 작업**:
- [ ] Loki Pod Running 확인: `kubectl get pods -n logging`
- [ ] PVC 바인딩 확인: `kubectl get pvc -n logging`
- [ ] 로그 수집 테스트: LogQL 쿼리 실행
- [ ] Grafana에서 로그 조회 확인

### Phase 2: Loki 안정화 (2주차)

**통합 작업**:
- [ ] Grafana Data Source 추가 (Loki)
- [ ] 애플리케이션별 로그 대시보드 생성

**최적화 작업**:
- [ ] Fluent Bit 필터 조정 (불필요한 로그 제외)
- [ ] 로그 레벨 필터링 설정 (ERROR, WARN, INFO)
- [ ] 라벨 전략 수립 (namespace, app, pod)

**모니터링 작업**:
- [ ] Loki 리소스 사용률 추적 (1주간)
- [ ] 디스크 사용량 증가 추이 분석
- [ ] LogQL 쿼리 응답 시간 측정

### Phase 3: EFK 병행 운영 (3-4주차)

**EFK 배포**:
- [ ] Elasticsearch Helm Chart 배포 (3 replicas, StatefulSet)
- [ ] Fluentd DaemonSet 배포
- [ ] Kibana Deployment 배포
- [ ] Istio VirtualService 설정 (Kibana 접근)

**이중 수집 설정**:
- [ ] Fluent Bit Output 이중 설정 (Loki + Fluentd)
- [ ] Elasticsearch 인덱스 생성 확인
- [ ] Kibana Index Pattern 생성

**안정성 검증** (2주):
- [ ] Elasticsearch 클러스터 상태 모니터링
- [ ] 로그 수집률 비교 (Loki vs Elasticsearch)
- [ ] 검색 성능 비교 테스트
- [ ] Kibana 대시보드 초안 작성

### Phase 4: EFK 전환 (5주차)

**전환 작업**:
- [ ] Fluent Bit Output을 Elasticsearch만 활성화
- [ ] 전환 후 1시간: 5분 간격 모니터링
- [ ] 전환 후 24시간: 1시간 간격 모니터링

**Loki 정리**:
- [ ] Loki Deployment 중지
- [ ] Loki Service 삭제
- [ ] Loki PVC 90일간 유지 (Retain 정책, GKE 클러스터 교체 주기)
- [ ] ArgoCD Loki Application 비활성화

**검증**:
- [ ] 로그 수집률 > 95% 확인
- [ ] Elasticsearch 클러스터 안정성 확인
- [ ] 주요 애플리케이션 로그 정상 수집 확인

### Phase 5: EFK 최적화 (6주차 이후)

**자동화 설정**:
- [ ] ILM (Index Lifecycle Management) 정책 적용
  - [ ] Hot phase: 0-7일
  - [ ] Warm phase: 8-30일
  - [ ] Cold phase: 31-60일
  - [ ] Delete: 60일 이상
- [ ] Elasticsearch Curator 설정 (자동 정리)

**대시보드 구축**:
- [ ] 애플리케이션별 로그 현황 대시보드
- [ ] 에러 로그 집계 대시보드
- [ ] 응답 시간 분석 대시보드
- [ ] 트래픽 추이 대시보드

**알림 설정**:
- [ ] 에러 급증 알림 (임계값: 평균의 300%)
- [ ] 응답 시간 초과 알림 (> 3초)
- [ ] Elasticsearch 클러스터 상태 알림

**성능 튜닝**:
- [ ] Shard 크기 최적화 (목표: 10-50GB per shard)
- [ ] Replica 수 조정
- [ ] JVM Heap 튜닝

**최종 정리**:
- [ ] Loki PV 삭제 검토 (90일 후, GKE 클러스터 교체 시점)
- [ ] 문서 업데이트 (운영 가이드)

---

## 예상 비용 분석

### Phase 1-2: Loki Stack 운영 비용

| 항목 | 사양 | 월 비용 | 비고 |
|------|------|---------|------|
| **Storage** | 30Gi (Standard PD) | $3 | Retain 정책 적용 |
| **CPU/Memory** | 500m CPU, 1Gi RAM | $0 | 기존 노드 리소스 활용 |
| **총 비용** | - | **$3/월** | 최소 비용으로 시작 |

### Phase 3 이후: EFK Stack 운영 비용

| 항목 | 사양 | 월 비용 | 비고 |
|------|------|---------|------|
| **Elasticsearch Storage** | 30Gi (10Gi × 3 replicas) | $3 | Retain 정책 적용 |
| **추가 GKE 노드** | e2-standard-2 × 1 | $50-80 | Elasticsearch 전용 |
| **총 비용** | - | **$53-83/월** | Loki 대비 18-28배 |

**비용 증가율**: Loki ($3/월) → EFK ($53-83/월)

### 비용 절감 옵션

**Option 1: Elasticsearch 단일 노드 운영**
- 설정: Replicas 3 → 1
- 적용 시기: 개발/테스트 환경
- 절감 효과: 약 60% 절감 ($53-83 → $25-35/월)
- 트레이드오프: 고가용성 포기

**Option 2: ILM (Index Lifecycle Management) 활용**
- 전략: Hot → Warm → Cold → Delete
- 효과: 스토리지 효율 30-50% 향상
- 예상 절감: $5-10/월
- 추천: Phase 5에서 적용

**Option 3: 로그 보존 기간 단축**
- 현재: 90일 보존
- 변경: 60일 또는 30일 보존
- 절감 효과: 스토리지 30-60% 감소
- 트레이드오프: 장기 분석 제약

**권장 전략**:
- 소규모 앱이므로 현재 30Gi 설정으로도 충분
- Phase 5에서 실제 사용량 확인 후 Option 2 (ILM) 적용

---

## 참고 자료

### 공식 문서 및 가이드

**Loki**:
- 공식 문서: https://grafana.com/docs/loki/latest/
- LogQL 쿼리 가이드: https://grafana.com/docs/loki/latest/logql/
- Helm Chart: https://github.com/grafana/loki/tree/main/production/helm/loki

**EFK Stack**:
- Elasticsearch 공식 문서: https://www.elastic.co/guide/en/elasticsearch/reference/current/
- Fluentd 공식 문서: https://docs.fluentd.org/
- Kibana 공식 문서: https://www.elastic.co/guide/en/kibana/current/
- Fluent Bit 공식 문서: https://docs.fluentbit.io/

**Helm Charts**:
- Elasticsearch Helm: https://github.com/elastic/helm-charts/tree/main/elasticsearch
- Fluentd Helm: https://github.com/fluent/helm-charts
- Kibana Helm: https://github.com/elastic/helm-charts/tree/main/kibana
- Fluent Bit Helm: https://github.com/fluent/helm-charts/tree/main/charts/fluent-bit

**Kubernetes 관련**:
- StorageClass 문서: https://kubernetes.io/docs/concepts/storage/storage-classes/
- PersistentVolume Retain: https://kubernetes.io/docs/concepts/storage/persistent-volumes/#retain

### 관련 프로젝트 문서

- [ArgoCD ApplicationSets](../../charts/argocd/applicationsets/)
- [OpenEBS Values](../../charts/argocd/applicationsets/valuefiles/prod/openebs/values.yaml)
- [Loki Values](../../charts/argocd/applicationsets/valuefiles/prod/loki/values.yaml)

---

**문서 정보**:
- **작성자**: DevOps Team
- **최초 작성**: 2025-12-22
- **최종 업데이트**: 2025-12-22
- **버전**: 1.0
- **다음 리뷰**: Phase 1 완료 후 (예정: 2025년 1월 1주)
- **승인자**: -
- **상태**: Planning → 승인 대기

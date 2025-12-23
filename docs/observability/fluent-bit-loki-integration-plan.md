# Fluent Bit - Loki 통합 계획서

**작성일**: 2025-12-23
**작성자**: DevOps Team
**상태**: 승인 대기
**목표**: 모든 애플리케이션 로그를 Loki로 중앙 집중식 수집

---

## 문제 상황

### 현재 상태

| 항목 | 상태 | 비고 |
|------|------|------|
| **Loki** | ✅ 배포 완료 | SimpleScalable 모드, logging namespace |
| **Fluent Bit** | ❌ 미배포 | DaemonSet 없음 |
| **reviewmaps 로그** | ✅ 출력 중 | stdout으로 JSON 형식 로그 |
| **ojeomneo 로그** | ✅ 출력 중 | stdout으로 텍스트 + JSON 형식 로그 |
| **로그 수집** | ❌ 불가능 | Fluent Bit 부재로 Loki로 전송 안 됨 |

### 문제점 분석

**핵심 문제**: Fluent Bit DaemonSet이 배포되지 않아 애플리케이션 로그가 Loki로 수집되지 않음

**확인 내용**:
- Loki는 정상 배포: \`loki-0\` (2/2 Running), \`loki-gateway\` (1/1 Running)
- loki-canary DaemonSet만 존재: Loki health check용, 로그 수집 기능 없음
- reviewmaps, ojeomneo Pod에 Fluent Bit sidecar 없음
- Fluent Bit DaemonSet 부재

**영향**:
- 중앙 집중식 로그 모니터링 불가
- 장애 대응 시 Pod별 개별 로그 확인 필요
- Pod 재시작 시 로그 유실
- Grafana로 통합 분석 불가

---

## 목표 상태

### 구성 개요

| 컴포넌트 | 역할 | 배포 형태 |
|----------|------|----------|
| **Loki** | 로그 저장 및 쿼리 | StatefulSet (1 replica) |
| **Fluent Bit** | 로그 수집 및 전송 | DaemonSet (모든 노드) |
| **Grafana** | 로그 시각화 | Deployment (기존) |

### 기대 효과

**즉시 효과**:
- ✅ 모든 애플리케이션 로그 중앙 집중화
- ✅ Grafana Explore로 LogQL 쿼리 가능
- ✅ namespace/pod/container 별 로그 필터링

**장기 효과**:
- ✅ 90일간 로그 보존 및 분석
- ✅ 장애 대응 시간 단축 (Pod별 조회 불필요)
- ✅ 대시보드 및 알림 기반 모니터링

---

## 구현 계획

### Phase 1: Fluent Bit Helm Chart 배포 (1일)

#### 1.1 Helm Chart 준비

**디렉토리 구조**:
```
charts/helm/prod/
└── fluent-bit/
    ├── Chart.yaml
    ├── values.yaml
    └── values-override.yaml
```

**Chart.yaml 내용**:
- Chart: \`fluent/fluent-bit\`
- Version: \`0.47.0\` (App Version: 3.2.2)
- 최신 안정 버전 사용

#### 1.2 핵심 설정

**values-override.yaml 주요 설정**:

**기본 설정**:
- DaemonSet 배포 (모든 노드에 1개씩)
- namespace: \`logging\`
- serviceAccount 생성

**로그 수집 설정**:
- Input: Kubernetes Pod 로그 (tail)
- Path: \`/var/log/containers/*.log\`
- Parser: docker, cri

**Loki 출력 설정**:
- Output: Loki HTTP
- Host: \`loki-gateway.logging.svc.cluster.local\`
- Port: \`80\`
- Labels: \`{job="fluent-bit", namespace="$kubernetes['namespace_name']", pod="$kubernetes['pod_name']", container="$kubernetes['container_name']"}\`

**필터 설정**:
- Kubernetes 메타데이터 추가
- namespace, pod, container 이름 태깅
- kube-system 네임스페이스 제외 (Optional)

**리소스 설정**:
- CPU: requests 100m, limits 200m
- Memory: requests 128Mi, limits 256Mi

#### 1.3 ArgoCD 통합

**파일 위치**: \`charts/argocd/configurations/prod/logging-prom-fluent-bit-cfg.yaml\`

**설정 내용**:
- env: \`prod\`
- chartName: \`fluent-bit\`
- appName: \`fluent-bit\`
- namespace: \`logging\`
- repoURL: \`https://github.com/ggorockee/infra\`
- revision: \`main\`

**ArgoCD ApplicationSet 연동**:
- 기존 \`prod-applicationsets-logging.yaml\`에서 자동 인식
- Pattern: \`logging-prom-*.yaml\`

### Phase 2: 배포 및 검증 (0.5일)

#### 2.1 Git 배포 프로세스

**배포 절차**:
1. Feature 브랜치 생성: \`git checkout -b feature/add-fluent-bit-to-loki\`
2. 파일 추가:
   - \`charts/helm/prod/fluent-bit/Chart.yaml\`
   - \`charts/helm/prod/fluent-bit/values.yaml\`
   - \`charts/helm/prod/fluent-bit/values-override.yaml\`
   - \`charts/argocd/configurations/prod/logging-prom-fluent-bit-cfg.yaml\`
3. Git 커밋 및 푸시
4. Pull Request 생성
5. 리뷰 후 main 브랜치에 병합
6. ArgoCD 자동 Sync (약 1-2분)

#### 2.2 배포 확인

**Pod 상태 확인**:
- DaemonSet 배포 확인: 모든 노드에 1개씩 (2/2 Ready)
- Pod 상태: Running
- 로그 확인: Loki 연결 성공 메시지

**로그 수집 확인**:
- Grafana Explore에서 LogQL 쿼리 테스트
- reviewmaps 로그: \`{namespace="reviewmaps"}\`
- ojeomneo 로그: \`{namespace="ojeomneo"}\`
- 최근 5분간 로그 확인

### Phase 3: 최적화 및 미세 조정 (0.5일)

#### 3.1 로그 필터링 최적화

**제외 대상**:
- kube-system namespace (시스템 로그 제외)
- istio-system namespace (Optional)
- 테스트/개발 namespace (Optional)

**파싱 최적화**:
- JSON 형식 로그 파싱
- 타임스탬프 필드 추출
- log level 필드 추가

#### 3.2 대시보드 구성

**Grafana 대시보드**:
- 애플리케이션별 로그 현황
- 에러 로그 집계 (ERROR, WARN)
- 요청별 로그 추적 (trace ID 기반)

#### 3.3 모니터링 및 알림

**리소스 모니터링**:
- Fluent Bit CPU/Memory 사용률
- 로그 전송 지연 시간
- Loki 디스크 사용률

---

## 수정할 파일 목록

### 1. 새로 생성할 파일

| 파일 경로 | 설명 | 우선순위 |
|----------|------|----------|
| \`charts/helm/prod/fluent-bit/Chart.yaml\` | Fluent Bit Helm Chart 정의 | 필수 |
| \`charts/helm/prod/fluent-bit/values.yaml\` | 기본 values (비어있거나 최소 설정) | 필수 |
| \`charts/helm/prod/fluent-bit/values-override.yaml\` | Loki 연동 및 필터 설정 | 필수 |
| \`charts/argocd/configurations/prod/logging-prom-fluent-bit-cfg.yaml\` | ArgoCD 설정 | 필수 |

### 2. 수정할 파일

| 파일 경로 | 수정 내용 | 우선순위 |
|----------|----------|----------|
| \`argocd_yaml/prod-applicationsets-logging.yaml\` | 수정 불필요 (Pattern에 자동 포함) | 확인만 |

### 3. 문서 파일

| 파일 경로 | 설명 |
|----------|------|
| \`docs/observability/fluent-bit-loki-integration-plan.md\` | 본 계획서 |

---

## 예상 Chart.yaml 내용

```yaml
apiVersion: v2
name: fluent-bit
description: Fluent Bit log processor for Kubernetes
type: application
version: 0.1.0
appVersion: "3.2.2"

dependencies:
  - name: fluent-bit
    version: "0.47.0"
    repository: https://fluent.github.io/helm-charts
```

---

## 예상 values-override.yaml 핵심 설정

### 기본 설정

```yaml
kind: DaemonSet

serviceAccount:
  create: true
  name: fluent-bit

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

### Input 설정

```yaml
config:
  inputs: |
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On
```

### Filter 설정

```yaml
config:
  filters: |
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        Keep_Log            Off
        K8S-Logging.Parser  On
        K8S-Logging.Exclude On
```

### Output 설정

```yaml
config:
  outputs: |
    [OUTPUT]
        Name              loki
        Match             *
        Host              loki-gateway.logging.svc.cluster.local
        Port              80
        Labels            job=fluent-bit, namespace=$kubernetes['namespace_name'], pod=$kubernetes['pod_name'], container=$kubernetes['container_name']
        Auto_Kubernetes_Labels On
```

---

## ArgoCD 설정 파일

**파일명**: \`charts/argocd/configurations/prod/logging-prom-fluent-bit-cfg.yaml\`

```yaml
env: prod
revision: main
chartName: fluent-bit
appName: fluent-bit
repoURL: https://github.com/ggorockee/infra
namespace: logging
```

---

## 검증 체크리스트

### Phase 1: 배포 준비

- [ ] Feature 브랜치 생성: \`feature/add-fluent-bit-to-loki\`
- [ ] \`charts/helm/prod/fluent-bit/\` 디렉토리 생성
- [ ] \`Chart.yaml\` 작성
- [ ] \`values.yaml\` 작성
- [ ] \`values-override.yaml\` 작성 (Loki 연동 설정)
- [ ] \`charts/argocd/configurations/prod/logging-prom-fluent-bit-cfg.yaml\` 작성
- [ ] Git 커밋 및 PR 생성

### Phase 2: 배포 및 기본 검증

- [ ] PR 리뷰 및 main 브랜치 병합
- [ ] ArgoCD 자동 Sync 확인 (1-2분)
- [ ] DaemonSet 배포 확인: 모든 노드에 Pod 생성
- [ ] Pod 상태 확인: Running (2/2 Ready)
- [ ] Pod 로그 확인: Loki 연결 성공 메시지

### Phase 3: 로그 수집 검증

- [ ] Grafana Explore 접속
- [ ] LogQL 쿼리: \`{namespace="reviewmaps"}\` 테스트
- [ ] LogQL 쿼리: \`{namespace="ojeomneo"}\` 테스트
- [ ] 최근 5분간 로그 수집 확인
- [ ] JSON 형식 로그 파싱 확인

### Phase 4: 최적화

- [ ] 불필요한 namespace 제외 (kube-system)
- [ ] 로그 필터링 설정 추가
- [ ] Grafana 대시보드 초안 작성
- [ ] 리소스 사용률 모니터링 시작 (1주)

---

## 롤백 계획

### 롤백 조건

| 조건 | 임계값 | 대응 |
|------|--------|------|
| Fluent Bit Pod 실패 | 1개 노드에서라도 실패 | 설정 재검토 |
| 로그 수집률 | < 90% | 필터 설정 확인 |
| Loki 연결 실패 | 5분 이상 지속 | DNS/Service 확인 |
| 리소스 초과 | CPU > 500m or Memory > 512Mi | 리소스 증량 |

### 롤백 절차

**빠른 롤백** (긴급 상황):
1. ArgoCD에서 \`fluent-bit\` Application 비활성화
2. DaemonSet 삭제: 모든 Fluent Bit Pod 제거
3. 소요 시간: 1분 이내
4. 데이터 손실: 비활성화 기간 로그만 (애플리케이션 Pod 로그는 유지)

**점진적 롤백** (설정 문제):
1. \`values-override.yaml\` 수정
2. Git 커밋 및 푸시
3. ArgoCD 자동 Sync
4. 소요 시간: 2-3분
5. 데이터 손실: 없음

---

## 리소스 예상

### Fluent Bit 리소스

| 항목 | 노드당 사용량 | 전체 (2 노드) |
|------|---------------|----------------|
| **CPU** | 100-200m | 200-400m |
| **Memory** | 128-256Mi | 256-512Mi |
| **비용** | $0 | $0 (기존 노드 활용) |

**참고**:
- 기존 GKE 노드: e2-standard-2 (2 vCPU, 8GB RAM)
- Fluent Bit는 경량 로그 수집기로 추가 노드 불필요

### Loki 리소스 (기존 유지)

| 항목 | 사용량 | 비고 |
|------|--------|------|
| **CPU** | 500m | 기존 설정 |
| **Memory** | 1Gi | 기존 설정 |
| **Storage** | 30Gi | gcp-standard-rwo-retain |
| **비용** | $3/월 | 기존 유지 |

---

## 기대 효과

### 즉시 효과 (1주 내)

| 항목 | Before | After |
|------|--------|-------|
| **로그 접근** | \`kubectl logs\` 개별 조회 | Grafana Explore 통합 조회 |
| **로그 보존** | Pod 생명주기에 종속 | 90일간 중앙 저장 |
| **검색 속도** | 1 Pod당 5-10초 | 1초 내 모든 Pod 검색 |
| **장애 대응** | 10-15분 | 2-3분 |

### 장기 효과 (1개월 후)

**운영 효율화**:
- 장애 대응 시간: 10-15분 → 2-3분
- 로그 분석 시간: 30분 → 5분
- 여러 Pod 동시 모니터링 가능

**모니터링 강화**:
- 대시보드 기반 실시간 모니터링
- 에러 로그 집계 및 패턴 분석
- trace ID 기반 요청 추적

---

## 참고 자료

### 공식 문서

**Fluent Bit**:
- 공식 문서: https://docs.fluentbit.io/
- Kubernetes Filter: https://docs.fluentbit.io/manual/pipeline/filters/kubernetes
- Loki Output: https://docs.fluentbit.io/manual/pipeline/outputs/loki
- Helm Chart: https://github.com/fluent/helm-charts/tree/main/charts/fluent-bit

**Loki**:
- LogQL 쿼리: https://grafana.com/docs/loki/latest/logql/
- Labels Best Practices: https://grafana.com/docs/loki/latest/best-practices/

### 프로젝트 문서

- [Loki to EFK 마이그레이션 계획](./loki-to-efk-migration-plan.md)
- [ArgoCD ApplicationSets](../../argocd_yaml/prod-applicationsets-logging.yaml)

---

**문서 정보**:
- **작성자**: DevOps Team
- **최초 작성**: 2025-12-23
- **최종 업데이트**: 2025-12-23
- **버전**: 1.0
- **다음 리뷰**: Phase 1 완료 후
- **승인자**: 대기 중
- **상태**: 승인 대기 → 사용자 컨펌 필요

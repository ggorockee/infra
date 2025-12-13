# GKE Autopilot 비용 최적화 및 운영 전략

## GKE Autopilot 개요

### AWS EKS와의 비교

| 측면 | AWS EKS | GCP GKE Autopilot |
|-----|---------|-------------------|
| 제어 영역 비용 | $0.10/시간 (월 $73) | 무료 |
| 노드 관리 | 수동 (EC2 직접 관리) | 자동 (Google 관리) |
| 스케일링 | Manual/Cluster Autoscaler | 자동 (Pod 기반) |
| 보안 패치 | 수동 적용 | 자동 적용 |
| 최소 구성 | 2개 노드 권장 | 노드 수 신경 안 써도 됨 |
| 비용 모델 | 노드 단위 과금 | Pod 리소스 단위 과금 |

## 비용 최적화 전략: 월 예산 10만원 ($75) 제약

### 예산 제약 사항

**월 예산 상한선**: 10만원 (약 $75)
**GKE 사용 가능 예산**: $75 (DB 제외)

### Autopilot 과금 방식

**과금 단위**: Pod의 요청(request) CPU/메모리 기준
- vCPU: $0.0446/vCPU/hour
- Memory: $0.0049/GB/hour

**계산 예시** (2 CPU, 4GiB Pod 1개 기준):
- CPU 비용: 2 × $0.0446 × 730시간 = $65.12/월
- 메모리 비용: 4 × $0.0049 × 730시간 = $14.31/월
- **Pod 1개 총 비용: 월 $79.43**
- **⚠️ 주의**: 단일 Pod만으로 예산 초과!

### 워크로드 리소스 설정

**권장 Pod 리소스 설정**:

**소규모 서비스 (API, 웹서버)**:
```yaml
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 500m
    memory: 1Gi
```
- **월 비용**: $8~10/Pod

**중규모 서비스 (백엔드)**:
```yaml
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi
```
- **월 비용**: $20~25/Pod

**대규모 서비스 (데이터 처리)**:
```yaml
resources:
  requests:
    cpu: 2000m
    memory: 4Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```
- **월 비용**: $79/Pod

### 예산 내 워크로드 구성 (월 $75 제약)

**전략 1: 최소 리소스 구성 (권장)**

- API 서버: 1 Pod × 250m CPU × 512Mi RAM = $10/월
- Admin 서버: 1 Pod × 100m CPU × 256Mi RAM = $4/월
- Worker (CronJob): 주 3회 실행, 500m CPU × 1Gi RAM = $3/월
- **총 비용**: 월 $17 (예산의 23% 사용)
- **여유 예산**: $58 (확장 가능)

**전략 2: 균형 구성**

- API 서버 (HPA): min 1, max 3 Pods × 500m CPU × 1Gi RAM
  - 평시: 1 Pod = $20/월
  - 피크: 3 Pods = $60/월
- Admin 서버: 1 Pod × 250m CPU × 512Mi RAM = $10/월
- **평시 총 비용**: 월 $30 (예산의 40%)
- **피크 총 비용**: 월 $70 (예산의 93%)

**전략 3: 공격적 확장 (한계 사용)**

- API 서버: 2 Pods × 500m CPU × 1Gi RAM = $40/월
- Admin 서버: 1 Pod × 250m CPU × 512Mi RAM = $10/월
- Worker: 1 Pod × 500m CPU × 1Gi RAM = $20/월
- **총 비용**: 월 $70 (예산의 93% 사용)
- **⚠️ 주의**: HPA 확장 여유 거의 없음

**⛔ 예산 초과 구성 (비권장)**

- API 서버: 2 Pods × 500m CPU × 1Gi RAM = $40/월
- Admin 서버: 1 Pod × 250m CPU × 512Mi RAM = $8/월
- Worker: 1 Pod × 1000m CPU × 2Gi RAM = $35/월
- **총 비용**: 월 $83 (예산 초과 $8)

### 예산 비교

| 구성 | AWS EKS | GKE Autopilot (예산 내) |
|-----|---------|------------------------|
| 제어 영역 | $73/월 | 무료 |
| 워크로드 | $30/월 (노드) | $17~70/월 (Pod) |
| **총 비용** | $103/월 | $17~70/월 |
| **예산 대비** | 37% 초과 | 예산 내 |

## HPA (Horizontal Pod Autoscaler) 설정

### CPU 기반 Auto Scaling

**목표**: 트래픽에 따라 Pod 수 자동 조정

**설정 예시**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-server-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-server
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**비용 변화**:
- 평시 (2 Pods): $40/월
- 피크 시 (10 Pods): $200/월
- **평균 비용**: $60~80/월 (피크가 전체의 20%라 가정)

### 메모리 기반 Auto Scaling

**메모리 민감 워크로드용**:
```yaml
metrics:
- type: Resource
  resource:
    name: memory
    target:
      type: Utilization
      averageUtilization: 80
```

## 비용 최적화 체크리스트

### 1. 리소스 Right-Sizing

**방법**:
- GKE 사용량 메트릭 모니터링 (Cloud Monitoring)
- 실제 사용량 기준으로 request 조정
- Over-provisioning 제거

**예시**:
- 기존: 1000m CPU request, 실제 사용 300m → 낭비 700m
- 최적화: 500m CPU request → 월 $20 절감

### 2. Spot VM (Preemptible Pods) 사용

**Standard Mode에서만 가능** (Autopilot은 미지원)

**대안**: Autopilot에서는 Spot 미지원, 대신 다음 전략 활용
- 리소스 효율적 설정
- HPA로 불필요한 Pod 제거
- Batch 작업은 Cloud Run Jobs 검토

### 3. 개발 환경 자동 종료

**야간/주말 클러스터 종료**:
- 개발 환경 GKE는 업무 시간만 운영
- CronJob으로 자동 start/stop (kubectl scale)
- **절감액**: 약 65% (주 5일 × 8시간 가동)

### 4. Namespace별 리소스 쿼터 설정

**과도한 리소스 요청 방지**:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
```

## Node/Pod 업그레이드 전략

### Autopilot의 자동 업그레이드

**장점**:
- Google이 노드 OS, Kubernetes 버전 자동 관리
- 보안 패치 자동 적용
- 다운타임 최소화 (롤링 업데이트)

### Release Channel 선택

| 채널 | Kubernetes 버전 | 안정성 | 권장 환경 |
|-----|----------------|-------|---------|
| Rapid | 최신 버전 (1~2주 후) | 낮음 | 개발/테스트 |
| Regular | 안정화 버전 (2~3개월 후) | 중간 | 스테이징 |
| Stable | 검증된 버전 (3~4개월 후) | 높음 | 프로덕션 |

**권장 설정**:
- 개발: Rapid 또는 Regular
- 프로덕션: Stable

### Maintenance Window 설정

**목적**: 업그레이드 시간대 제어

**설정 예시**:
- 요일: 화요일, 수요일
- 시간: 새벽 2~6시 (한국 시간)
- 빈도: 주 1회

**Terraform 설정**:
```
resource "google_container_cluster" "autopilot" {
  maintenance_policy {
    daily_maintenance_window {
      start_time = "18:00"  # UTC (한국 시간 새벽 3시)
    }
  }
}
```

### PodDisruptionBudget (PDB) 설정

**목적**: 업그레이드 중 최소 가용 Pod 수 보장

**설정 예시**:
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-server-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: api-server
```

**효과**:
- 업그레이드 중에도 최소 1개 Pod 유지
- 무중단 배포 보장

### 애플리케이션 준비 사항

**1. Health Check 필수 설정**:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

**2. Graceful Shutdown 구현**:
- SIGTERM 신호 처리
- 진행 중인 요청 완료 후 종료
- `terminationGracePeriodSeconds: 30` 설정

**3. Rolling Update 전략**:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

## 스토리지 전략

### 1. 영구 데이터 스토리지

**Persistent Volume (PV) 옵션**:

| 스토리지 타입 | AWS 대응 | 용도 | 비용 |
|------------|---------|------|------|
| Persistent Disk (Standard) | EBS gp2 | 일반 데이터 | $0.040/GB/월 |
| Persistent Disk (SSD) | EBS gp3 | 고성능 DB | $0.170/GB/월 |
| Cloud Filestore | EFS | 공유 파일 시스템 | $0.20/GB/월 |
| Cloud Storage | S3 | 객체 스토리지 | $0.020/GB/월 |

**권장 전략**:
- **데이터베이스**: Cloud SQL (Persistent Disk 불필요)
- **파일 업로드**: Cloud Storage + CDN
- **공유 설정 파일**: ConfigMap/Secret
- **임시 데이터**: emptyDir

### 2. ConfigMap/Secret으로 설정 관리

**용도**:
- 애플리케이션 설정 파일
- 환경 변수
- 데이터베이스 연결 정보 (Secret)

**장점**:
- 스토리지 비용 없음
- Git으로 버전 관리
- 배포 시 자동 적용

### 3. emptyDir (임시 볼륨)

**용도**:
- 캐시 데이터
- 임시 파일 처리
- 로그 버퍼

**특징**:
- Pod 재시작 시 데이터 삭제
- 추가 비용 없음
- 빠른 로컬 스토리지

### 4. Cloud Storage 통합

**정적 파일, 미디어 저장**:
- 사용자 업로드 이미지
- 비디오 파일
- 대용량 로그 아카이브

**접근 방법**:
- Workload Identity로 인증 (Key 파일 불필요)
- `google-cloud-storage` SDK 사용

**비용**:
- Standard Storage: $0.020/GB/월
- Nearline (월 1회 접근): $0.010/GB/월

### 5. 로깅 전략

**옵션 1: Cloud Logging (권장)**
- GKE 로그 자동 수집
- 검색, 필터링, 알림
- 월 50GB 무료, 이후 $0.50/GB

**옵션 2: 직접 관리**
- Fluentd + Cloud Storage
- 비용 절감 (장기 보관용)
- 복잡한 설정

**권장**: Cloud Logging + 30일 이후 Cloud Storage 아카이브

## 예산 제약 내 최적 구성 (월 $75 한도)

### 권장 구성: 균형 전략 (전략 2)

**시나리오**: API + Admin 서비스 (Worker는 CronJob)

**구성**:
```
1. API 서버 (HPA)
   - requests: 500m CPU, 1Gi RAM
   - limits: 1000m CPU, 2Gi RAM
   - HPA: min 1, max 3 (CPU 70%)
   - 평시: 1 Pod = $20/월
   - 피크: 3 Pods = $60/월

2. Admin 서버 (고정)
   - requests: 250m CPU, 512Mi RAM
   - limits: 500m CPU, 1Gi RAM
   - Replicas: 1 (고정)
   - 비용: $10/월

3. Worker (CronJob)
   - requests: 500m CPU, 1Gi RAM
   - schedule: "0 2 * * *" (매일 새벽 2시)
   - 실행 시간: 10분/일
   - 비용: ~$3/월
```

**총 리소스 및 비용**:
- **평시**: 0.75 CPU, 1.5Gi RAM → **월 $33**
- **피크 시**: 2.25 CPU, 4.5Gi RAM → **월 $73**
- **예산 준수율**: 97% (여유 $2)

**비용 절감 포인트**:
- HPA로 불필요한 Pod 제거 (야간/주말)
- Worker를 CronJob으로 실행 (필요시만)
- Admin은 1개 Pod로 충분 (트래픽 적음)

### 추가 비용 절감 전략 (예산 압박 시)

**더 낮은 리소스 설정**:
```
1. API 서버
   - requests: 250m CPU, 512Mi RAM
   - HPA: min 1, max 2
   - 평시: $10/월, 피크: $20/월

2. Admin 서버
   - requests: 100m CPU, 256Mi RAM
   - 비용: $4/월

3. Worker (CronJob)
   - 주 3회 실행
   - 비용: $2/월
```

**초절약 구성 총 비용**: **월 $16~26**
- 예산 사용률: 21~35%
- 여유 예산: $49~59

## 모니터링 및 알림 설정

### Cloud Monitoring 지표

**필수 모니터링 항목**:
- Pod CPU/메모리 사용률
- HPA 스케일링 이벤트
- 노드 업그레이드 상태
- 애플리케이션 에러율

**알림 설정**:
- CPU 사용률 >80% (5분 지속)
- 메모리 사용률 >85%
- Pod OOMKilled 발생
- Deployment 롤아웃 실패

### 비용 알림

**Budget Alerts 설정**:
- **예산 $75/월 설정** (10만원 한도)
- 50% ($37), 75% ($56), 90% ($67) 도달 시 알림
- Slack/Email 연동
- 일일 비용 추이 모니터링

## 체크리스트

- [ ] GKE Autopilot Release Channel 선택 (Stable 권장)
- [ ] Maintenance Window 설정 (새벽 시간대)
- [ ] 각 서비스별 리소스 request/limit 설정
- [ ] HPA 설정 (트래픽 변동 대응)
- [ ] PodDisruptionBudget 설정 (고가용성)
- [ ] Health Check (liveness/readiness) 구현
- [ ] Graceful Shutdown 구현
- [ ] 스토리지 전략 결정 (Cloud Storage vs Persistent Disk)
- [ ] Cloud Logging 활성화 및 보관 정책 설정
- [ ] Cloud Monitoring 알림 설정
- [ ] Budget Alert 설정 (비용 관리)
- [ ] 개발 환경 자동 종료 스케줄 설정

## 다음 단계

컨펌 필요 사항:
1. 예상 워크로드(서비스 개수, Pod 수)는?
2. 트래픽 패턴은? (평시 vs 피크 시간대)
3. 개발 환경 자동 종료 허용 여부?
4. **월 예산 상한선**: 10만원 ($75) ✅ 확정

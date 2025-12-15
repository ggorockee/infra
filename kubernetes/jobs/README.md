# Kubernetes Jobs

Kubernetes Job 리소스를 관리하는 디렉토리입니다.

## 디렉토리 구조

각 Job은 목적별로 독립된 디렉토리에서 관리됩니다:

- `cloud-sql-restore/` - Cloud SQL 데이터베이스 백업 복원 Job

## Best Practices

### 폴더 구조

각 Job 디렉토리는 다음 구조를 따릅니다:

| 파일명 | 용도 | 필수 여부 |
|--------|------|-----------|
| `README.md` | Job 사용 가이드 | 필수 |
| `job.yaml` | Job 리소스 정의 | 필수 |
| `service-account.yaml` | ServiceAccount 및 RBAC | 선택 |
| `external-secret.yaml` | Secret Manager 연동 | 선택 |
| `configmap.yaml` | 환경 변수 설정 | 선택 |

### 네이밍 컨벤션

**Job 이름**:
- 형식: `[목적]-[대상]-[상세]`
- 예시: `cloud-sql-restore-ojeomneo`, `data-migration-v2`

**Labels**:

| 레이블 | 용도 | 예시 |
|--------|------|------|
| `app` | 애플리케이션 그룹 | `cloud-sql-restore` |
| `database` | 데이터베이스 이름 | `ojeomneo` |
| `version` | 버전 정보 | `v1` |
| `env` | 환경 | `prod`, `dev` |

**Namespace**:
- 기본: `default`
- 운영 Job: `operations`
- 마이그레이션: `migrations`

### Job 설정 권장사항

#### TTL (Time To Live)

```yaml
spec:
  ttlSecondsAfterFinished: 3600  # 1시간 후 자동 삭제
```

- 일반 작업: `3600` (1시간)
- 중요 작업: `86400` (24시간)
- 디버깅용: `7200` (2시간)

#### Backoff Limit

```yaml
spec:
  backoffLimit: 3  # 최대 3번 재시도
```

- 네트워크 작업: `3-5`
- 멱등성 작업: `1-2`
- Critical 작업: `0` (재시도 없음)

#### Restart Policy

```yaml
spec:
  template:
    spec:
      restartPolicy: Never  # 또는 OnFailure
```

- `Never`: 실패 시 Pod 유지 (로그 확인 용이)
- `OnFailure`: 실패 시 자동 재시작

#### 리소스 제한

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

- 경량 작업: `100m / 256Mi`
- 중간 작업: `200m / 512Mi`
- 대용량 작업: `500m / 1Gi`

## 일반적인 Job 패턴

### 1. 일회성 작업

데이터 마이그레이션, 백업 복원 등

- `restartPolicy: Never`
- `backoffLimit: 3`
- `ttlSecondsAfterFinished: 3600`

### 2. 주기적 작업 (CronJob)

정기 백업, 클린업 등

- CronJob 리소스 사용
- 스케줄 표현식: `0 2 * * *` (매일 새벽 2시)
- `successfulJobsHistoryLimit: 3`

### 3. 병렬 처리

대량 데이터 처리 등

- `parallelism: 5` (동시 실행 Pod 수)
- `completions: 10` (총 완료 목표 수)

## 배포 및 관리

### Job 실행

```
kubectl apply -f [job-directory]/
```

### 상태 확인

```
kubectl get jobs
kubectl describe job [job-name]
kubectl get pods -l job-name=[job-name]
```

### 로그 확인

```
kubectl logs job/[job-name]
kubectl logs -f [pod-name]
```

### Job 삭제

```
kubectl delete job [job-name]
```

## 보안 고려사항

### ServiceAccount

- 최소 권한 원칙 적용
- 필요한 리소스에만 접근 권한 부여
- Workload Identity 사용 (GCP)

### Secret 관리

- External Secrets Operator 사용
- Secret Manager (GCP) 또는 AWS Secrets Manager 연동
- 환경 변수로 주입, 파일로 저장하지 않음

### 네트워크 정책

- 필요한 서비스에만 접근 허용
- NetworkPolicy 리소스 정의

## 모니터링

### 메트릭 확인

- Prometheus: Job 완료율, 실행 시간
- Grafana: Job 실행 대시보드

### 알림 설정

- Job 실패 시 Slack/Email 알림
- 장시간 실행 Job 감지
- 리소스 부족 알림

## 문제 해결

### Job이 시작되지 않음

- ServiceAccount 권한 확인
- Pod 스케줄링 실패: `kubectl describe pod`
- 리소스 제한 확인

### Job이 반복 실패

- 로그 확인: `kubectl logs`
- backoffLimit 증가 고려
- 재시도 간격 조정

### Job이 완료되지 않음

- Timeout 설정 확인
- activeDeadlineSeconds 추가
- 리소스 제한 증가

## 참고 자료

- Kubernetes Jobs: https://kubernetes.io/docs/concepts/workloads/controllers/job/
- CronJobs: https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
- Best Practices: https://kubernetes.io/docs/concepts/configuration/overview/

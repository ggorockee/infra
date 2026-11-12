# CLAUDE.md

This file provides guidance to Claude Code when working with infrastructure code in this repository.

## 프로젝트 개요

Kubernetes 기반 멀티 클라우드 인프라 관리 저장소입니다. AWS와 GCP 환경을 모두 지원하며, Helm 차트, Terraform, ArgoCD를 활용한 GitOps 방식의 인프라 관리를 수행합니다.

## 인프라 용어 대응 규칙

인프라 관련 질의 시 AWS/GCP 개념을 상호 대응하여 설명합니다.

### 컴퓨팅 서비스

| AWS | GCP | 설명 |
|-----|-----|------|
| EC2 (Elastic Compute Cloud) | Compute Engine | 가상 머신 인스턴스 |
| ECS (Elastic Container Service) | Cloud Run | 컨테이너 실행 서비스 |
| EKS (Elastic Kubernetes Service) | GKE (Google Kubernetes Engine) | 관리형 Kubernetes 클러스터 |
| Lambda | Cloud Functions | 서버리스 함수 실행 |
| Fargate | Cloud Run (serverless) | 서버리스 컨테이너 실행 |
| Elastic Beanstalk | App Engine | PaaS 애플리케이션 플랫폼 |
| Lightsail | Compute Engine (preemptible) | 간소화된 가상 서버 |

### 스토리지 서비스

| AWS | GCP | 설명 |
|-----|-----|------|
| S3 (Simple Storage Service) | Cloud Storage | 객체 스토리지 |
| EBS (Elastic Block Store) | Persistent Disk | 블록 스토리지 (VM 볼륨) |
| EFS (Elastic File System) | Filestore | 관리형 NFS 파일 시스템 |
| Glacier | Cloud Storage (Archive) | 장기 보관 아카이브 스토리지 |
| Storage Gateway | Transfer Appliance | 하이브리드 클라우드 스토리지 |

### 데이터베이스 서비스

| AWS | GCP | 설명 |
|-----|-----|------|
| RDS (Relational Database Service) | Cloud SQL | 관리형 관계형 데이터베이스 |
| Aurora | Cloud Spanner | 글로벌 분산 관계형 DB |
| DynamoDB | Firestore / Bigtable | NoSQL 데이터베이스 |
| ElastiCache (Redis) | Memorystore | 관리형 인메모리 캐시 |
| DocumentDB | Firestore | 문서 기반 NoSQL DB |
| Neptune | N/A | 그래프 데이터베이스 |

### 네트워킹 서비스

| AWS | GCP | 설명 |
|-----|-----|------|
| VPC (Virtual Private Cloud) | VPC (Virtual Private Cloud) | 가상 사설 네트워크 |
| Route 53 | Cloud DNS | DNS 관리 서비스 |
| CloudFront | Cloud CDN | 콘텐츠 전송 네트워크 (CDN) |
| ELB (Elastic Load Balancer) | Cloud Load Balancing | 로드 밸런서 |
| Direct Connect | Cloud Interconnect | 전용 네트워크 연결 |
| API Gateway | API Gateway / Cloud Endpoints | API 관리 및 배포 |
| Transit Gateway | Cloud Router | 멀티 VPC 연결 허브 |

### 보안 및 인증

| AWS | GCP | 설명 |
|-----|-----|------|
| IAM (Identity and Access Management) | IAM (Identity and Access Management) | 인증 및 권한 관리 |
| KMS (Key Management Service) | Cloud KMS | 암호화 키 관리 |
| Secrets Manager | Secret Manager | 비밀 정보 관리 |
| Certificate Manager | Certificate Manager | SSL/TLS 인증서 관리 |
| WAF (Web Application Firewall) | Cloud Armor | 웹 애플리케이션 방화벽 |
| GuardDuty | Security Command Center | 위협 탐지 서비스 |
| Shield | Cloud Armor | DDoS 방어 |

### 모니터링 및 로깅

| AWS | GCP | 설명 |
|-----|-----|------|
| CloudWatch | Cloud Monitoring (Stackdriver) | 모니터링 및 로깅 |
| CloudWatch Logs | Cloud Logging | 로그 수집 및 분석 |
| X-Ray | Cloud Trace | 분산 추적 (tracing) |
| CloudTrail | Cloud Audit Logs | API 호출 감사 로그 |
| EventBridge | Eventarc / Cloud Pub/Sub | 이벤트 기반 통합 |

### CI/CD 및 개발 도구

| AWS | GCP | 설명 |
|-----|-----|------|
| CodePipeline | Cloud Build | CI/CD 파이프라인 |
| CodeBuild | Cloud Build | 빌드 서비스 |
| CodeDeploy | Cloud Deploy | 배포 자동화 |
| CodeCommit | Cloud Source Repositories | Git 저장소 |
| ECR (Elastic Container Registry) | Artifact Registry / GCR | 컨테이너 이미지 저장소 |

### 메시징 및 통합

| AWS | GCP | 설명 |
|-----|-----|------|
| SQS (Simple Queue Service) | Cloud Tasks / Pub/Sub | 메시지 큐 서비스 |
| SNS (Simple Notification Service) | Cloud Pub/Sub | 게시/구독 메시징 |
| Kinesis | Dataflow / Pub/Sub | 실시간 데이터 스트리밍 |
| Step Functions | Workflows | 워크플로우 오케스트레이션 |

### 관리 및 거버넌스

| AWS | GCP | 설명 |
|-----|-----|------|
| CloudFormation | Deployment Manager / Terraform | IaC (Infrastructure as Code) |
| Systems Manager | Cloud Operations | 시스템 관리 도구 |
| Organizations | Resource Manager | 다중 계정/프로젝트 관리 |
| Config | Cloud Asset Inventory | 리소스 구성 관리 |
| Cost Explorer | Cost Management | 비용 분석 도구 |

## 응답 규칙

### 질의 응답 패턴

AWS 용어로 질의가 들어온 경우:
```
질문: "EKS 클러스터 설정 방법은?"

답변:
## AWS EKS (Elastic Kubernetes Service)
[EKS 관련 설명]

## GCP 대응 개념: GKE (Google Kubernetes Engine)
- GCP에서는 GKE를 사용하여 동일한 관리형 Kubernetes 클러스터 제공
- 주요 차이점: [차이점 설명]
- GCP에서의 설정: [GKE 설정 방법 간략 설명]
```

GCP 용어로 질의가 들어온 경우:
```
질문: "Cloud SQL 백업 설정은?"

답변:
## GCP Cloud SQL
[Cloud SQL 관련 설명]

## AWS 대응 개념: RDS (Relational Database Service)
- AWS에서는 RDS를 사용하여 동일한 관리형 관계형 데이터베이스 제공
- 주요 차이점: [차이점 설명]
- AWS에서의 설정: [RDS 백업 설정 방법 간략 설명]
```

### 응답 시 포함할 내용

1. **질의된 클라우드의 상세 설명** (주요 내용)
2. **대응 개념 명시** (간략한 비교)
3. **주요 차이점** (아키텍처, 기능, 가격 등)
4. **유사점** (공통 기능 및 사용 사례)

### 멀티 클라우드 관점 제시

가능한 경우 다음 내용 추가:
- 멀티 클라우드 전략 관점에서의 장단점
- 클라우드 중립적인 솔루션 제안 (Kubernetes, Terraform 등)
- 마이그레이션 고려사항

## 프로젝트 구조

```
infra/
├── aws/                        # AWS 관련 인프라 코드
│   ├── terraform/             # Terraform IaC
│   └── cloudFormation/        # CloudFormation 템플릿
├── charts/                     # Helm 차트 (클라우드 중립)
│   ├── argocd/               # ArgoCD 설정
│   └── helm/                 # 애플리케이션 Helm 차트
│       ├── dev/              # 개발 환경
│       │   └── fridge2fork/  # Fridge2Fork 앱
│       └── prod/             # 프로덕션 환경
│           ├── ojeomneo/     # Ojeomneo 앱
│           └── reviewmaps/   # ReviewMaps 앱
├── istio-config/              # Istio 서비스 메시 설정
├── istio-main-gateway/        # Istio 게이트웨이
└── claudedocs/                # Claude 분석 문서
```

## 주요 기술 스택

- **IaC**: Terraform, CloudFormation
- **Container Orchestration**: Kubernetes (EKS/GKE)
- **GitOps**: ArgoCD
- **Package Management**: Helm
- **Service Mesh**: Istio
- **Monitoring**: kube-prometheus-stack (Prometheus, Grafana, Alertmanager) + Prometheus Pushgateway — Loki, fluent-bit, otel-collector, SigNoz는 2026-11-13 제거됨 (아래 "운영 현황" 참고)

## Git 워크플로우 규칙

### Feature 브랜치 전략 (필수)

**🔴 CRITICAL: main 브랜치 직접 작업 금지**

- **절대 금지**: main 브랜치에 직접 커밋 또는 푸시
- **필수 사항**: 모든 작업은 feature 브랜치에서 수행
- **PR 필수**: feature 브랜치 작업 완료 후 Pull Request 생성

### 작업 흐름

1. **현재 브랜치 확인**
   ```bash
   git status
   git branch
   ```

2. **main 브랜치인 경우**: Feature 브랜치 생성 필수
   ```bash
   # ❌ 잘못된 방법: main에서 직접 작업
   # main 브랜치에서 커밋하면 안됨!

   # ✅ 올바른 방법: feature 브랜치 생성
   git checkout -b feature/작업-내용-설명
   ```

3. **Feature 브랜치 네이밍 규칙**
   - `feature/기능명`: 새 기능 추가
   - `fix/버그명`: 버그 수정
   - `refactor/대상`: 리팩토링
   - `docs/문서명`: 문서 작업
   - `chore/작업명`: 설정 및 기타 작업

4. **작업 및 커밋**
   ```bash
   # feature 브랜치에서 작업
   git add .
   git commit -m "feat: 작업 내용"
   git push origin feature/작업-내용-설명
   ```

5. **Pull Request 생성**
   - GitHub에서 PR 생성
   - 리뷰 후 승인
   - Squash and Merge로 main에 병합
   - 병합 후 feature 브랜치 삭제

### 커밋 요청 시 동작

사용자가 "커밋해줘" 또는 "커밋해달라"고 요청한 경우:

**Case 1: 현재 main 브랜치인 경우**
```bash
# 1. Feature 브랜치 생성
git checkout -b feature/적절한-브랜치명

# 2. 변경사항 커밋
git add .
git commit -m "feat: 작업 내용"

# 3. 원격에 푸시
git push origin feature/적절한-브랜치명

# 4. 사용자에게 안내
"main 브랜치 보호를 위해 feature/적절한-브랜치명 브랜치를 생성하여 커밋했습니다.
PR을 생성하여 main에 병합해주세요."
```

**Case 2: 이미 feature 브랜치인 경우**
```bash
# 정상적으로 커밋 진행
git add .
git commit -m "feat: 작업 내용"
git push origin 현재-브랜치명
```

### 체크리스트

커밋 전 필수 확인사항:
- [ ] 현재 브랜치가 main이 아닌가? (`git branch` 확인)
- [ ] Feature 브랜치 네이밍이 적절한가?
- [ ] 커밋 메시지가 명확한가?
- [ ] main 브랜치에 직접 푸시하려는 것은 아닌가?

### 예외 상황

**절대 허용되지 않는 작업:**
- ❌ `git push origin main` (main 브랜치 직접 푸시)
- ❌ main 브랜치에서 `git commit` (main 브랜치 직접 커밋)
- ❌ `git push --force origin main` (main 브랜치 force push)

**허용되는 작업:**
- ✅ `git pull origin main` (main 브랜치 최신화)
- ✅ `git checkout main` (main 브랜치로 전환만)
- ✅ feature 브랜치에서의 모든 git 작업

## 문서 작성 규칙

### Markdown 문서 코드 블록 제한

**목적**: Context 효율화 및 문서 크기 최소화

**허용되는 코드 블록**:
- ✅ JSON 데이터 형식
- ✅ Markdown 표 형식
- ✅ YAML 설정 예시 (최소한으로)

**금지되는 코드 블록**:
- ❌ Bash/Shell 스크립트
- ❌ Python 코드
- ❌ JavaScript/TypeScript 코드
- ❌ Terraform 코드
- ❌ Dockerfile 내용
- ❌ 기타 모든 프로그래밍 언어 코드

**대체 방법**:
```
❌ 잘못된 예시:
## 설치 방법
```bash
npm install package-name
```

✅ 올바른 예시:
## 설치 방법
- 패키지 설치: `npm install package-name`
- 서버 실행: `npm run dev`
```

**예외 사항**:
- 설정 파일 예시는 JSON 또는 YAML 형식으로만 제공
- 명령어는 인라인 코드(``)로 표시
- 복잡한 스크립트는 별도 파일로 분리하고 문서에는 설명만 작성

**적용 범위**:
- `*.md` 파일 (README, CLAUDE.md, 문서 등)
- `claudedocs/` 디렉토리 내 모든 문서
- Git 저장소의 모든 마크다운 문서

## Terraform 문서 동기화 규칙

**⚠️ 중요 규칙**: Terraform 리소스 변경 시 문서 동기화 필수

### 문서 동기화 트리거

다음 작업 시 `gcp/terraform/TERRAFORM_RESOURCES.md`를 **반드시** 업데이트:

1. **리소스 생성/삭제**
   - `terraform apply`로 리소스 추가/제거
   - 모듈 활성화/비활성화 (`main.tf` 주석 처리 변경)
   - Phase 진행 (Phase 1 → Phase 2 → Phase 3)

2. **리소스 이름 변경**
   - 네이밍 컨벤션 변경
   - 환경 변경 (prod/dev/staging)
   - 도메인 변경

3. **비용 변동**
   - 새로운 리소스 추가로 인한 비용 증가
   - 월별 실제 비용 확인 후 업데이트

### 업데이트 체크리스트

Terraform 변경 시 다음을 확인하고 업데이트:

- [ ] **현재 배포된 리소스 테이블** 업데이트
- [ ] **Phase 2 예정 리소스** 상태 변경 (⏸️ Pending → ✅ Active)
- [ ] **리소스 히스토리** 섹션에 변경 내역 추가
- [ ] **예상 월별 비용** 재계산
- [ ] **Terraform 모듈 구조** 상태 업데이트
- [ ] **최종 업데이트 날짜** 수정 (YYYY-MM-DD 형식)

### 커밋 메시지 규칙

Terraform 변경 시 커밋 메시지에 문서 업데이트 명시:

```
feat: Cloud SQL 모듈 추가

- Cloud SQL PostgreSQL 인스턴스 생성
- TERRAFORM_RESOURCES.md 업데이트
- Phase 2 진행률: 1/7 완료
```

### 자동화 검증

다음 파일이 함께 변경되었는지 확인:
- `gcp/terraform/environments/prod/main.tf` 변경
- `gcp/terraform/TERRAFORM_RESOURCES.md` 업데이트

누락 시 PR 리뷰에서 반드시 지적하고 수정 요청

## Terraform 로컬 검증 제한

**🔴 중요 규칙**: 로컬 환경에서 Terraform Plan/Apply 실행 불가

### 제한 사유
- GCP 인증 정보는 GitHub Actions Secrets에만 존재
- 로컬 환경에는 GCP 서비스 계정 키가 없음
- 보안상 로컬에 프로덕션 인증 정보 저장 금지

### 검증 프로세스
1. **코드 작성**: 로컬에서 Terraform 코드 작성
2. **Git 푸시**: Feature 브랜치에 커밋 및 푸시
3. **CI/CD 검증**: GitHub Actions에서 자동으로 `terraform plan` 실행
4. **결과 확인**: PR에서 Terraform Plan 결과 확인
5. **승인 및 배포**: PR 승인 후 자동으로 `terraform apply` 실행

### 작업 플로우
- ✅ `terraform init`: 로컬에서 실행 가능 (provider 다운로드)
- ✅ `terraform validate`: 로컬에서 실행 가능 (문법 검증)
- ✅ `terraform fmt`: 로컬에서 실행 가능 (포맷팅)
- ❌ `terraform plan`: GitHub Actions에서만 실행
- ❌ `terraform apply`: GitHub Actions에서만 실행

### 주의사항
- 로컬에서 `terraform plan` 시도 시 인증 에러 발생
- 검증은 반드시 Git을 통한 CI/CD 파이프라인으로 수행
- PR 생성 후 Terraform Plan 결과를 확인하여 변경사항 검증

## 운영 현황 (prod, 2026-11-13 기준)

새 세션에서 prod 작업 전 이 섹션을 먼저 확인합니다. 상세 설계는 `claudedocs/monitoring-grafana-prometheus-design.md`.

### 클러스터 및 배포 경로

| 항목 | 값 |
|------|-----|
| GKE 클러스터 | `woohalabs-prod-gke` (zone `asia-northeast3-a`, 노드 e2-highmem-2 × 2) |
| GCP 프로젝트 | `yanggo-514212` (번호 488227135751) |
| kubectl context | `gke_yanggo-514212_asia-northeast3-a_woohalabs-prod-gke` |
| 공개 IP (Istio ingress) | `34.22.107.0`, DNS `*.ggorockee.com` 와일드카드 |

| 대상 | 배포 방법 | 주의 |
|------|-----------|------|
| ArgoCD 자체 | 로컬 차트 `charts/helm/prod/argo-cd`로 설치된 Helm 릴리스 `argocd` (Terraform 모듈은 주석 처리) | 머지 후 `helm upgrade argocd ./charts/helm/prod/argo-cd -n argocd` 직접 실행 필요 |
| ApplicationSet | `argocd_yaml/*.yaml` | GitOps 대상 아님 → 머지 후 `kubectl apply -f argocd_yaml/<파일>` 직접 실행 |
| 앱/인프라 차트 | ApplicationSet이 `charts/argocd/configurations/prod/*-cfg.yaml` 파일마다 Application 생성 | main 머지 시 자동 sync |
| 리뷰맵 이미지 | reviewmaps 레포 main 머지 → CI가 이미지 빌드 → infra에 태그 PR 생성·자동 머지 | infra `charts/helm/prod/reviewmaps/values.yaml` 태그만 바뀜 |

| ApplicationSet | generator 파일 패턴 | values |
|----------------|--------------------|--------|
| `infra-apps-prod` | `apps-*.yaml` | 차트 `values.yaml` |
| `infra-infrastructure-prod` | `*-cfg.yaml` (monitoring-, istio-, apps- 제외) | 차트 `values.yaml` |
| `istio-applicationsets` | `istio-*.yaml` | 차트 `values.yaml` |
| `infra-monitoring-prod` | `monitoring-*-cfg.yaml` | multi-source: 차트 `values.yaml`(upstream 원본) + `charts/argocd/applicationsets/valuefiles/prod/<valuesDir>/values.yaml`(override) |

### 모니터링 스택

| 구성요소 | 위치 | 비고 |
|----------|------|------|
| kube-prometheus-stack 93.2.2 | 차트 `charts/helm/prod/kube-prometheus-stack`, override `valuefiles/prod/kube-prometheus-stack/values.yaml` | Prometheus 15일 보관, Alertmanager, Grafana, kube-state-metrics |
| Prometheus Pushgateway 3.11.2 | 차트 `charts/helm/prod/prometheus-pushgateway`, override `valuefiles/prod/prometheus-pushgateway/values.yaml` | go-scraper 실행 결과 수신, PVC로 재시작 시 보존 |
| Grafana | `https://monitoring.ggorockee.com` (Istio VS `grafana-vs`) | Google OAuth + 관리자 `woohaen88` (비밀번호는 GSM `prod-monitoring-smtp-credentials.password`) |
| Prometheus / Alertmanager | 외부 노출 없음 | 필요 시 `kubectl -n monitoring port-forward` |
| GKE Managed Prometheus | 비활성화 (Terraform `managed_prometheus.enabled=false`) | 다시 켜지 않도록 주의 |
| Cloud Logging | 시스템 로그만 수집 (앱 로그 미수집) | CronJob Pod는 완료 1시간 후 삭제 → 과거 Job 로그 없음 |

kube-prometheus-stack 차트에 직접 추가한 파일 (upstream 업그레이드 시 반드시 보존):

| 파일 | 역할 |
|------|------|
| `templates/custom-externalsecrets.yaml` | values `customExternalSecrets`로 GSM → Secret 생성 (OAuth/관리자, 리뷰맵 DB, Alertmanager 설정) |
| `templates/custom-alertmanager-templates.yaml` | 메일 템플릿 ConfigMap `alertmanager-email-templates` |
| `templates/grafana/configmap-custom-dashboards.yaml` | `dashboards/*.json`을 Grafana sidecar용 ConfigMap으로 생성 |
| `files/alertmanager.yaml.tmpl` | Alertmanager 설정 (ESO 템플릿, 수신자/라우팅) |
| `files/alertmanager-email.tmpl` | 메일 제목·본문 템플릿 |
| `dashboards/*.json` | 커스텀 대시보드 |

### Grafana 대시보드

| 대시보드 | UID | 내용 |
|----------|-----|------|
| ReviewMaps CronJob & DB 적재 (Home) | `reviewmaps-cronjob` | CronJob 성공/실패, Cloud SQL campaign 적재 건수 |
| ReviewMaps 수집 서버 | `reviewmaps-scraper` | 지금 수집 중인 Job·키워드·진행률, go-scraper 키워드별 마지막 실행 결과 (Pushgateway) |
| ReviewMaps HTTP Metrics | `reviewmaps-http-metrics` | Go API 서버 요청 수, P95, 5xx |

모든 대시보드 상단에 "이 대시보드 보는 법"(🟢정상/🟠경고/🔴알람 범위표)이 있고, 차트별 ⓘ 설명이 있습니다. 차트 색상 기준값 = 알림 규칙 기준값이므로 한쪽을 바꾸면 다른 쪽도 같이 바꿉니다. 새 대시보드도 같은 형식(상단 범위표 + 차트별 [무엇]/[보는 법]/[범위])을 유지합니다.

### 알림 (Alertmanager → 메일)

| 항목 | 값 |
|------|-----|
| 수신자 | `woohaen88@gmail.com` (`files/alertmanager.yaml.tmpl`에 고정) |
| 발신 | GSM의 SMTP 계정(Gmail) 그대로 사용, 표시 이름 "ReviewMaps 알림" — `noreply@woohalabs.com`은 SPF(Zoho만 허용) 실패로 스팸 처리되므로 쓰지 않음 |
| 제목 접두어 | `[ERROR]` critical, `[ALERT]` warning, `[INFO]` info, `[RESOLVED]` 해제 |
| 기본 규칙 info 알림 | 메일 미발송 (CPUThrottlingHigh 등) |

| 알림 | 조건 | 등급 |
|------|------|------|
| ReviewmapsJobSucceeded | CronJob Job 성공 (Job당 1통, 해제 메일 없음) | INFO |
| ReviewmapsJobFailed | Job 최종 실패 | ERROR |
| ReviewmapsCronJobNotSucceeded | CronJob 26시간 미성공 | ERROR |
| ReviewmapsJobRunningTooLong | Job 2시간 초과 실행 | ALERT |
| ReviewmapsScraperKeywordFailed | 키워드 실행 실패 15분 | ERROR |
| ReviewmapsScraperKeywordStale | 키워드 26시간 미성공 | ERROR |
| ReviewmapsScraperZeroItems | 성공했지만 0건 수집 | ALERT |
| ReviewmapsScraperItemsDropped | 전일 대비 50% 미만 (전일 20건 이상) | ALERT |
| ReviewmapsScraperEnrichErrorsHigh | 네이버 API 보강 에러율 20% 초과 | ALERT |
| ReviewmapsScraperServerAPIError | 키워드 알림 서버 API 실패 | ALERT |
| ReviewmapsServerHighErrorRate | API 5xx 5% 초과 10분 | ERROR |
| ReviewmapsServerSlow | API P95 1초 초과 15분 (헬스체크, `/v1/internal/*` 내부 배치 제외) | ALERT |
| ReviewmapsServerDown | API 서버 메트릭 수집 불가 5분 | ERROR |

수집 서버 알림은 스크래퍼별로 묶어 한 통으로 발송합니다. 키워드를 설정에서 빼면 Pushgateway에 이전 그룹이 남아 KeywordStale이 계속 발생하므로, Pushgateway에서 해당 그룹을 삭제합니다 (`DELETE /metrics/job/reviewmaps_scraper/scraper@base64/<..>/keyword@base64/<..>`).

### 리뷰맵 운영 메모

| 항목 | 내용 |
|------|------|
| CronJob (KST) | inflexer 00:05 (키워드 81개, 약 12분), reviewnote 02:00 (약 2~3분), cleanup 05:00 (수 초) |
| 저장 방식 | go-scraper는 DELETE 후 INSERT → `created_at` = 마지막 수집 시각 |
| cleanup | 물리 삭제가 아니라 soft delete (`deleted_at`). DB 조회 시 항상 `deleted_at IS NULL` 조건 |
| cleanup 기준일 | KST 자정 (`cleanup.StartOfDay`). `time.Truncate(24h)`는 UTC 기준이라 사용 금지 |
| 수집 메트릭 | go-scraper가 키워드 시작 시 running=1, 종료 시 결과+running=0을 `PUSHGATEWAY_URL`로 push (`internal/runstats`). grouping 값은 `@base64` 인코딩 (client_golang 기본 인코딩은 공백이 `+`로 저장됨) |
| 서버 /metrics | Fiber 라벨 문자열은 반드시 복사(`strings.Clone`) — zero-copy 버퍼 재사용으로 라벨 손상 시 /metrics 500 |
| GORM AutoMigrate | 운영 비활성 (`DB_AUTO_MIGRATE` 기본 false). Django 제약 이름 불일치 + go-scraper 소유 테이블 변경 위험. 스키마는 `server/migrations/*.sql` |
| DB 직접 조회 | 운영 DB 쓰기 금지. 확인은 Grafana `ReviewMaps-DB` 데이터소스 또는 읽기 전용 임시 Pod (`SET default_transaction_read_only = on`) |
| 수동 실행 | `kubectl -n reviewmaps create job --from=cronjob/<이름> <job이름>` |

### Secret / 인증

| 항목 | 내용 |
|------|------|
| External Secrets Operator | v0.9.11, ClusterSecretStore `gcpsm-secret-store`. Secret에만 쓸 수 있고 ConfigMap에는 못 씀 |
| ServerSideApply 앱의 ExternalSecret | ESO 기본값(`conversionStrategy`, `decodingStrategy`, `metadataPolicy`, `deletionPolicy`)을 명시하지 않으면 계속 OutOfSync |
| GSM 시크릿 JSON 형식 | 점이 들어간 평면 키 (`"google.clientId"`), 중첩 객체 아님 |
| Google OAuth 클라이언트 | `yanggo-514212` 프로젝트 웹 클라이언트 (Grafana, ArgoCD Dex 공용). 리디렉션 URI: `monitoring.ggorockee.com/login/generic_oauth`, `argocd.ggorockee.com/api/dex/callback`. 동의 화면 Testing 상태라 Test users만 로그인 가능 |
| 로컬 자격증명 파일 | `.secrets/` (gitignore). 예: `.secrets/oauth-client_yanggo-514212_monitoring-argocd.json` |
| ArgoCD 관리자 | `charts/helm/prod/argo-cd/values.yaml`의 `configs.rbac.policy.csv`에 직접 지정 (ExternalSecret 방식은 ConfigMap 대상이라 동작 안 함) |

### 권한 규칙

| 작업 | 허용 |
|------|------|
| kubectl 조회·운영 작업 | 자유 |
| gcloud get/list/describe/read | 자유 |
| gcloud create/update/put/delete (Secret 버전 추가, 클러스터 설정 변경 포함) | 실행 직전 개발자 승인 필수 |

### 검증 기준값 (2026-11-13 수동 실행)

평소 값과 비교할 때 참고합니다.

| 항목 | 값 |
|------|-----|
| inflexer | 키워드 81개 전부 성공, 수집 13,359 / 저장 13,038 / 신규 115, 키워드당 최대 약 17초 |
| reviewnote | 수집 1,600 / 저장 1,591, 약 131초 |
| cleanup | 4,259건 soft delete (기준일 수정 첫 실행), 약 3초 |
| 네이버 API (보강) | inflexer 호출 425 / 에러 0, reviewnote 호출 65 / 에러 0 |
| 내부 배치 API | `/v1/internal/process-campaign-alerts` P95 약 0.9초 (정상) |

### 2026-11-13 작업 이력 (PR)

| 레포 | PR | 내용 |
|------|-----|------|
| infra | #1118, #1119 | Grafana + Prometheus 재구축, ExternalSecret OutOfSync 수정 |
| infra | #1120 | GMP 비활성화 Terraform 반영 |
| infra | #1121 | `.secrets/` gitignore |
| infra | #1122 | ArgoCD 관리자 RBAC 수정 |
| infra | #1123, #1124 | 문서, Grafana Home 대시보드 |
| infra | #1125, #1128, #1130 | CronJob 성공/실패 메일, 메일 템플릿·수신자, From 주소 수정 |
| infra | #1127 | 서버 ServiceMonitor |
| infra | #1131, #1132 | Pushgateway, 수집 서버 대시보드·전 대시보드 범위/설명·알림 규칙 |
| infra | #1135, #1136 | 실행 중 Job 이름·경과 시간, 지금 수집 중인 키워드·진행률 패널 |
| infra | #1138 | 응답 지연 알림에서 내부 배치 API 제외 (수집 시간대 오탐) |
| reviewmaps | #275 | 서버 /metrics 500 수정 |
| reviewmaps | #276 | GORM AutoMigrate 운영 비활성화 |
| reviewmaps | #277 | go-scraper Pushgateway push |
| reviewmaps | #278 | cleanup KST 자정 기준일 수정 (11/12 마감 4,259건 하루 더 노출되던 문제) |
| reviewmaps | #279 | go-scraper 키워드 시작 시 running 표시 push |

## 주의사항

- **멀티 클라우드**: AWS와 GCP 개념을 상호 참조하여 설명
- **클라우드 중립적 접근**: 가능한 경우 Kubernetes, Helm 등 클라우드 중립적 솔루션 우선 제안
- **보안**: IAM, Secret 관리 시 각 클라우드의 베스트 프랙티스 준수
- **비용 최적화**: 각 클라우드의 가격 정책 차이 고려
- **Git 워크플로우**: main 브랜치 직접 작업 절대 금지, 항상 feature 브랜치 사용
- **문서 작성**: 프로그래밍 코드 블록 제외, JSON/표 형식만 허용
- **Terraform 문서 동기화**: 리소스 변경 시 TERRAFORM_RESOURCES.md 필수 업데이트
- **Terraform 검증**: 로컬에서는 불가능, Git CI/CD 파이프라인으로만 검증
- **prod 반영 확인**: 머지로 끝내지 않고 ArgoCD Synced/Healthy, Pod 상태, 실제 동작(메트릭·메일·로그)까지 확인
- **ArgoCD·ApplicationSet**: Git 머지만으로 반영되지 않음 → 위 "배포 경로" 표의 수동 명령 실행
- **모니터링 변경**: 대시보드 색상 기준과 알림 규칙 기준을 함께 변경, 대시보드는 범위표·차트 설명 형식 유지

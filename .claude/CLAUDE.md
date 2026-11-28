# CLAUDE.md

This file provides guidance to Claude Code when working with infrastructure code in this repository.

## 🔴 최우선 원칙 (모든 작업에 다른 규칙보다 먼저 적용)

1. **모든 것은 문서로 남긴다.** 결정·절차·겪은 문제·남은 일을 작업이 끝나기 전에 문서에 적는다. 문서 갱신이 빠진 작업은 끝난 작업이 아니다.
2. **모니터링할 수 없는 것은 관리할 수 없다.** 새로 만들거나 바꾼 것은 지표·대시보드·알림(또는 점검 날짜)까지 갖춰야 끝난 것이다. 확인하지 않은 상태를 정상으로 보고하지 않는다.

세부 기준과 어디에 무엇을 적는지는 `claudedocs/00-원칙.md`. 작업 시작 시 진행 중인 계획 문서(`claudedocs/planning/`, 로컬 전용)의 "다음 세션 시작 가이드"를 먼저 읽고, 앱 상태는 `python3 scripts/app-status.py`로 확인한다. 출시·광고 연동 절차와 겪은 문제는 `claudedocs/app-release-runbook.md`.

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
│           ├── ojeomneo/     # Ojeomneo 앱 (2026-11-15 중지, 차트만 보존)
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
- **Monitoring**: kube-prometheus-stack (Prometheus, Grafana, Alertmanager) + Prometheus Pushgateway + blackbox exporter + postgres-exporter — Loki, fluent-bit, otel-collector, SigNoz는 2026-11-13 제거됨 (아래 "운영 현황" 참고)

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

새 세션에서 prod 작업 전 이 섹션을 먼저 확인합니다. **앱(리뷰맵·돌려받엔·라익찍스) 운영·광고 작업은 로컬 전용 계획 문서 `claudedocs/planning/2026-11-app-ops-plan.md`의 "다음 세션 시작 가이드"부터 읽고, `python3 scripts/app-status.py`로 현재 상태를 확인합니다** (계획 문서는 금액이 있어 커밋하지 않음). 상세 설계는 `claudedocs/monitoring-grafana-prometheus-design.md`.

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
| 라익찍스 이미지 | like-zzix 레포 main 머지 → CI(`ci-server.yml`)가 `ggorockee/like-zzix-server` 빌드 → infra 태그 PR 생성·자동 머지 | infra `charts/helm/prod/like-zzix/values.yaml` 태그만 바뀜. like-zzix 레포에 DOCKERHUB_USERNAME/DOCKERHUB_TOKEN/INFRA_GITHUB_TOKEN 시크릿 필요 |
| 리뷰맵 관리자 | reviewmaps 레포 main 머지(`admin/**`) → CI(`ci-admin.yml`)가 `ggorockee/reviewmaps-admin:<날짜>-<커밋>` 빌드 → infra 태그 PR(`admin.image.tag`) 자동 머지 (저장소 변수 `ADMIN_AUTO_DEPLOY=true`) | https://admin.review-maps.com (Nuxt 정적 화면 + 서버 `/admin/v1`, 2026-11-27 Django에서 전환, infra #1227). 로그인은 Google(yanggo-514212 웹 클라이언트, JS 원본·리디렉션 URI 등록, 동의 화면 Test users 필요) + GSM `prod-reviewmaps-api-credentials`의 `ADMIN_EMAILS`, 예비 로그인은 `.secrets/README.md`. 서버 configMap·Secret만 바꾸면 Pod 재시작 필요(`kubectl -n reviewmaps rollout restart deploy/reviewmaps-server`). 되돌리기: #1227 revert (Django `20261110-7ed5b97`). 계정 추가·제거는 `claudedocs/app-release-runbook.md` 8-1 |
| 라익찍스 관리자 콘솔 이미지 | like-zzix 레포 main 머지(`admin/**`) → CI(`ci-admin.yml`)가 `ggorockee/like-zzix-admin` 빌드 → infra 태그 PR(`admin.image.tag`) 자동 머지 | https://like-zzix-admin.woohalabs.com. 로그인은 Google(yanggo-514212 웹 클라이언트, 승인된 JS 출처에 콘솔 주소 등록 필요) + GSM `prod-like-zzix-credentials`의 ADMIN_EMAILS. 같은 GSM 키로 Terraform이 Cloud SQL DB·사용자 `like_zzix`를 만듦 |
| iOS 앱 빌드·업로드 (세 앱 공통) | 각 앱 레포 Actions → `iOS Release` → Run workflow (빌드 번호 비우면 실행 시각, 업로드 끄면 빌드·서명만). `xcode-27` 러너(Xcode 27.2) | 개발 맥은 Intel이라 Xcode 27 불가(2027-04부터 iOS 27 SDK 필수). 시크릿 ASC_KEY_*, IOS_SIGNING_P12_*, IOS_BUILD_FILES_BASE64 (위치는 `.secrets/README.md`). 업로드 뒤 App Store Connect에서 버전에 빌드 연결·제출. 배포 인증서 만료 2027-11-26 |

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
| blackbox exporter 11.21.3 | 차트 `charts/helm/prod/prometheus-blackbox-exporter`, override `valuefiles/prod/prometheus-blackbox-exporter/values.yaml` | 외부 URL 9개(2xx) + 내부 Redis 2개(PING) (오점너 4개는 2026-11-15 제거) 접속 검사, 인증서 만료일. 대상 추가는 override `serviceMonitor.targets` |
| postgres-exporter 8.2.5 | 차트 `charts/helm/prod/prometheus-postgres-exporter`, override `valuefiles/prod/prometheus-postgres-exporter/values.yaml` | Cloud SQL `prod-woohalabs-cloudsql`(172.29.0.3, max_connections 100, 디스크 20GB 자동 확장). 계정은 Secret `grafana-reviewmaps-db` 재사용 |
| stackdriver-exporter 5.2.2 | 차트 `charts/helm/prod/prometheus-stackdriver-exporter`, override `valuefiles/prod/prometheus-stackdriver-exporter/values.yaml` | Cloud SQL CPU·메모리·디스크 (Cloud Monitoring → Prometheus, 2분 간격·2~5분 지연). Workload Identity: KSA `monitoring/prometheus-stackdriver-exporter` → GSA `monitoring-reader-prod` (`roles/monitoring.viewer`, Terraform `modules/monitoring`). 문서 `claudedocs/cloudsql-monitoring.md` |
| app-metrics-exporter (자체 차트) | 차트 `charts/helm/prod/app-metrics-exporter`(코드 `files/exporter.py`, ConfigMap 마운트), override `valuefiles/prod/app-metrics-exporter/values.yaml`의 `apps` 목록 | GA4(사용자·비정상 종료·AdMob 수입·Google Ads 비용), Firebase Remote Config 값, 스토어 공개·버전, app-ads.txt. GA4 1시간, 그 밖 10분 주기. Workload Identity: KSA `monitoring/app-metrics-exporter` → GSA `app-metrics-reader-prod`(GA4 속성 뷰어 + 앱 Firebase 프로젝트 `roles/cloudconfig.viewer`). 앱 출시 시 `released` 갱신. 문서 `claudedocs/app-metrics-monitoring.md` |
| 추가 수집 대상 | kube-prometheus-stack override `prometheus.additionalServiceMonitors` / `additionalPodMonitors`, cert-manager 차트 values | istiod, Istio ingress gateway(서비스별 요청·응답 코드·지연), ArgoCD, External Secrets, cert-manager (오점너 수집은 2026-11-15 중지로 제거) |
| Grafana | `https://monitoring.ggorockee.com` (Istio VS `grafana-vs`) | Google OAuth + 관리자 `woohaen88` (비밀번호는 GSM `prod-monitoring-smtp-credentials.password`) |
| Prometheus / Alertmanager | 외부 노출 없음 | 필요 시 `kubectl -n monitoring port-forward` |
| GKE Managed Prometheus | 비활성화 (Terraform `managed_prometheus.enabled=false`) | 다시 켜지 않도록 주의 |
| OpenTelemetry·SigNoz | **사용하지 않음** (2026-11-28 개발자 확인). 새 설정에 넣지 말 것 | go-scraper 설정의 주소는 2026-11-28 삭제 (전송 실패 로그 해결). 남은 코드·옛 설정은 `claudedocs/otel-signoz-cleanup.md` |
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
| 클러스터 전체 현황 | `cluster-overview` | 발생 중 알림, 서비스 접속 상태, 노드·용량, 워크로드, 서비스별 트래픽(Istio), 인증서, ArgoCD, Secret, Cloud SQL |
| ReviewMaps CronJob & DB 적재 (Home) | `reviewmaps-cronjob` | CronJob 성공/실패, Cloud SQL campaign 적재 건수 |
| ReviewMaps 수집 서버 | `reviewmaps-scraper` | 지금 수집 중인 Job·키워드·진행률, go-scraper 키워드별 마지막 실행 결과 (Pushgateway) |
| ReviewMaps HTTP Metrics | `reviewmaps-http-metrics` | Go API 서버 요청 수, P95, 5xx, 관리자 로그인·변경·세션·최근 변경 표(ReviewMaps-DB), 카테고리 매핑(미매핑 원본, 출처별 카테고리 없는 캠페인 비율) |
| 앱·광고·스토어 현황 | `app-ads-overview` | 세 앱의 사용자·신규, 비정상 종료, AdMob 광고 단위별 수입·eCPM, 앱 오프닝 표시율, Google Ads 비용·유입, 신규 사용자 1일·7일 잔존율(광고/그 외), 스토어 공개·버전·Remote Config 값, app-ads.txt |
| 라익찍스 (like-zzix) | `like-zzix` | API 서버 상태, 촬영 퍼널(프리셋 선택 → Perfect Match → 저장), 앱 버전 분포·업데이트 반응, 저장 실패·카메라 사용 불가 비율, 관리자 콘솔·DB 연결·프리셋 갱신 |

차트 색상 기준값 = 알림 규칙 기준값이므로 한쪽을 바꾸면 다른 쪽도 같이 바꿉니다. 대시보드를 새로 만들거나 고칠 때 아래 작성 규칙을 따릅니다 (사용자가 가독성을 직접 지적해 정한 규칙).

| 규칙 | 내용 |
|------|------|
| 범위표 | 맨 위 접힌 행 "📖 이 대시보드 보는 법 — 정상/경고/알람 범위표 (펼치기)" 안에 text 패널로 둠 (펼친 상태로 두면 첫 화면을 가림) |
| 차트 설명 | 모든 차트 ⓘ 에 [무엇] / [보는 법] / [범위] 3단 |
| 첫 화면 | 지금 상황(실행 중 Job, 수집 중 키워드, 진행률) → 요약 → 상세 표 → 추이 순 |
| 이름 표시 | 공통 접두어 제거: label_replace 정규식 `(?:reviewmaps-go-(?:cron-)?)?(.*)` (접두어 없는 이름도 매칭되도록 앞부분 선택적). 새 라벨명은 Prometheus 기본 라벨(`job` 등)과 겹치지 않게 (`name`, `jobname`) |
| 글자 크기 | 이름+값 stat 패널은 `options.text` titleSize 22 / valueSize 40 고정 (자동이면 긴 이름 때문에 작아짐) |
| 시간 표기 | 진행 중 경과 시간은 `dthms`(00:02:07), 긴 경과(시간 단위)는 `s` |
| 색상 | stat 배경은 `background_solid` (그라데이션은 글자 대비가 약함) |
| 빈 값 | `noValue`에 상황 문구 ("실행 중인 Job 없음" 등), 실행 중인데 값이 없을 수 있는 쿼리는 `or (0 * ...)`로 0 보장 |
| 검증 | 머지 후 실제 화면 캡처로 확인 (Playwright, 관리자 비밀번호는 브라우저에 입력하지 않고 로컬 프록시가 인증 헤더 주입) |

### 알림 (Alertmanager → 메일)

| 항목 | 값 |
|------|-----|
| 수신자 | `woohaen88@gmail.com` (`files/alertmanager.yaml.tmpl`에 고정) |
| 발신 | GSM의 SMTP 계정(Gmail) 그대로 사용, 표시 이름 "woohalabs 모니터링" — `noreply@woohalabs.com`은 SPF(Zoho만 허용) 실패로 스팸 처리되므로 쓰지 않음 |
| 제목 접두어 | `[CRITICAL]` critical(서비스 중단), `[ERROR]` error(기능 실패), `[WARN]` warning(정상 범위 벗어남), `[INFO]` info(참고), `[RESOLVED]` 해제 |
| 발송 범위 | 초기 단계라 INFO까지 전부 발송 (INFO는 해제 메일 없음). 줄일 때는 `files/alertmanager.yaml.tmpl`의 info 라우트 → warning 라우트 순으로 receiver를 `"null"`로 변경 |
| 반복 발송 | CRITICAL 2시간, ERROR 6시간, WARN 12시간, INFO 24시간 |
| 정상 범위·알림 기준 전체 | `claudedocs/monitoring-grafana-prometheus-design.md` 10.4, 대시보드 `cluster-overview` 범위표 |
| Istio 지표 주의 | `istio_*`는 ingress gateway에서만 수집하고 `source_*` 라벨은 labeldrop → 쿼리에 `source_workload` 조건을 쓰면 결과가 비어 알림이 영원히 안 울림 |
| 테스트 메일 | Alertmanager API(`/api/v2/alerts`)에 테스트 알림 POST. 같은 alertname·namespace면 상위 등급이 하위 등급을 억제하므로 등급마다 이름을 다르게 |

| 알림 | 조건 | 등급 |
|------|------|------|
| ReviewmapsJobSucceeded | CronJob Job 성공 (Job당 1통, 해제 메일 없음) | INFO |
| ReviewmapsJobFailed | Job 최종 실패 | ERROR |
| ReviewmapsCronJobNotSucceeded | CronJob 26시간 미성공 | ERROR |
| ReviewmapsJobRunningTooLong | Job 2시간 초과 실행 (reviewnote-detail 제외, 일부러 새벽 내내 실행) | WARN |
| ReviewmapsScraperKeywordFailed | 키워드 실행 실패 15분 | ERROR |
| ReviewmapsScraperKeywordStale | 키워드 26시간 미성공 | ERROR |
| ReviewmapsScraperZeroItems | 성공했지만 0건 수집 | WARN |
| ReviewmapsScraperItemsDropped | 전일 대비 50% 미만 (전일 20건 이상) | WARN |
| ReviewmapsScraperEnrichErrorsHigh | 네이버 API 보강 에러율 20% 초과 | WARN |
| ReviewmapsScraperServerAPIError | 키워드 알림 서버 API 실패 | WARN |
| ReviewnoteSessionExpiringSoon | 리뷰노트 세션 쿠키 만료 3일 미만 (갱신하라는 메일, 12시간마다 반복) | WARN |
| ReviewnoteSessionExpired | 세션 없음·만료·상세 API 401 (계정 제재도 401) | ERROR |
| ReviewnoteSessionExpiryUnknown | 세션 만료일 지표 없음 1시간 (만료 전 메일을 못 보내는 상태) | ERROR |
| ReviewnoteDetailBlocked | 상세 수집이 403·429·5xx로 멈춤 | ERROR |
| ReviewnoteDetailStalled | 상세 수집 실행 중인데 다음 요청 예정보다 10분 넘게 지남 | WARN |
| ReviewnoteDetailTargetsLow / ReviewnoteDetailIncomplete | 상세 대상 200건 미만 / 상세를 못 받은 여행 공고 20건 초과 | WARN |
| ReviewmapsServerHighErrorRate | API 5xx 5% 초과 10분 | ERROR |
| ReviewmapsServerSlow | API P95 1초 초과 15분 (헬스체크, `/v1/internal/*` 내부 배치 제외) | WARN |
| ReviewmapsServerDown | API 서버 메트릭 수집 불가 5분 | CRITICAL |
| ReviewmapsAdminLoginFailures | 관리자 로그인 실패·거부 10분 10회 초과 | WARN |
| ReviewmapsAdminUnauthorizedLogin | 허용 목록(ADMIN_EMAILS) 밖 계정 관리자 로그인 시도 | INFO |
| ReviewmapsCategoryUnmappedBacklog | 미매핑 원본 카테고리 50개 이상 7일 (관리자 화면 카테고리 매핑에서 처리) | INFO |
| LikeZzixServerDown | 라익찍스 API 메트릭 수집 불가 5분 | CRITICAL |
| LikeZzixHighErrorRate | 라익찍스 API 5xx 5% 초과 10분 | ERROR |
| LikeZzixSlow | 라익찍스 API P95 1초 초과 15분 | WARN |
| LikeZzixEventsRejected | 앱 이벤트 거부 지속 30분 (앱·서버 허용 목록 불일치) | WARN |
| LikeZzixPhotoSaveFailing | 1시간 사진 저장 실패율 20% 초과 (시도 5회 이상) | WARN |
| LikeZzixCameraUnavailableHigh | 1시간 카메라 실패(카메라 없음·열기 실패, 권한 거부 제외) 비율 20% 초과 (실행 5회 이상) | WARN |
| AppForceUpdateLockout / AppStoreListingMissing | 강제 업데이트 최소 버전 > 스토어 버전 10분 / 공개 앱이 스토어에서 30분 안 보임 | CRITICAL |
| AppMetricsExporterDown / AppAdsTxtInvalid / AdImpressionsZero / AppCrashFreeCritical | 수집기 중단 / app-ads.txt 이상 / 어제 광고 노출 0(사용자 5명 이상) / 7일 비정상 종료 없는 사용자 85% 미만 | ERROR |
| AppCrashFreeLow / AdRevenueDropped / AppOpenAdShowRateLow / AdsSpendWithoutInstalls / AppMetricsCollectStale | 95% 미만 / 수입 이전 7일의 50% 미만 / 표시율 40% 미만 / 7일 $3 초과인데 유입 0 / 지표 갱신 지연 | WARN |
| AdsCostOverDailyLimit / AdsCostUnbudgetedCampaign / AdsCostOverMonthlyLimit | 캠페인 하루 광고비가 예산의 2.2배 초과 / 예산 목록에 없는 캠페인에서 비용 / 이번 달이 (예산 합 × 30.4) 초과 → **바로 일시중지** | CRITICAL |
| AdsCostCollectFailing / AdsBudgetNotConfigured | 광고비 수집 1시간 중단·실패 / 예산 기준 없음 (비용 감시 멈춤) | ERROR |
| AdsCostOverBudget / AdsCostZeroWithBudget | 하루 예산의 1.5배 초과 / 예산이 있는데 36시간 비용 0 (수집 또는 게재 확인) | WARN |
| AdsCostIncurred | 어제 Google Ads 광고비 발생 (하루 한 번) | INFO |
| AppRemoteConfigChanged / AppRemoteConfigLatestBehind | Remote Config 변경 / latest가 스토어보다 하루 넘게 낮음 | INFO |

클러스터 전체 규칙 (kube-prometheus-stack override, 그룹 이름 기준):

| 그룹 | 주요 알림 (등급) |
|------|-----------------|
| cluster.nodes | Ready 노드 2대 미만 (CRITICAL), CPU 80% (WARN), 메모리 80% (WARN) / 95% (CRITICAL), 데이터 디스크 80% (WARN) |
| cluster.capacity | CPU/메모리 requests 예약률 85% (WARN), 배치 불가 Pod (ERROR) |
| cluster.workloads | 가용 Pod 0개 Deployment/StatefulSet (CRITICAL), 재시작 1회 (INFO) / 1시간 3회 (WARN), OOMKilled·시작 실패 (ERROR), 메모리 limit 90% (WARN) |
| cluster.storage | PVC 85% (WARN) |
| services.availability | 접속 검사 실패 3분 (CRITICAL), 접속 2초 초과 (WARN), 인증서 21일 미만 (WARN) / 7일 미만 (CRITICAL) |
| services.traffic | 5xx 5% 초과 (ERROR), P95 1초 초과 (WARN), 트래픽 어제 대비 30% 미만 / 5배 초과 (WARN, Grafana·ArgoCD 제외) |
| platform.* | ArgoCD OutOfSync (WARN) / Degraded·sync 실패 (ERROR) / 배포 완료 (INFO), 인증서 Not Ready (ERROR), ExternalSecret 실패 (ERROR), Istio 설정 거부 (WARN), DNS SERVFAIL (WARN) |
| database.* | Cloud SQL 접속 불가 (CRITICAL), 연결 80% (WARN), deadlock·긴 트랜잭션 (WARN), 캐시 적중률 90% 미만 (INFO), Redis 거부·메모리 (WARN) |
| database.cloudsql | Cloud SQL CPU 80% (WARN), 메모리 80% (WARN) / 95% (CRITICAL), 디스크 80% (WARN), 디스크 자동 확장 (INFO), 트랜잭션 ID 50% (WARN), 지표 수집 안 됨 (ERROR) |

기본 규칙 중 NodeMemoryHighUtilization, NodeCPUHighUsage는 위 cluster.nodes로 대체해 비활성화했습니다. Istio 지표의 `destination_service_name="unknown"`은 어떤 도메인에도 매칭되지 않는 요청(IP 직접 접근 스캐너)이고, 4xx 비율은 봇 요청이 많아 알림 없이 대시보드에서만 봅니다.

수집 서버 알림은 스크래퍼별로 묶어 한 통으로 발송합니다. 키워드를 설정에서 빼면 Pushgateway에 이전 그룹이 남아 KeywordStale이 계속 발생하므로, Pushgateway에서 해당 그룹을 삭제합니다 (`DELETE /metrics/job/reviewmaps_scraper/scraper@base64/<..>/keyword@base64/<..>`).

### 리뷰맵 운영 메모

| 항목 | 내용 |
|------|------|
| CronJob (KST) | inflexer 00:05 (키워드 81개, 약 12분), reviewnote 02:00 (약 2~3분), cleanup 05:00 (수 초), reviewnote-detail 00:00~08:00 (여행 상세를 천천히, 아래 줄), pickly 02:30 (피클리 공개 API, 약 30건, 끄기 `PICKLY_ENABLED`) |
| 리뷰노트 여행 상세 (reviewnote-detail, 2026-11-28~) | 목록 API는 한 조건당 **1,600건(16건×100쪽)까지만** 주므로 여행 categoryId로 걸러 받음(약 68쪽, 02:00 reviewnote 도 여행 목록을 추가로 받음). 로그인 필요한 상세 API에서 이용 가능·불가 요일·시간·당일 방문·예약 주의사항 수집 → `campaign_stay_detail`(원본) → campaign 컬럼 복사, 02:00 reviewnote 는 보관값을 붙여 저장. 차단 방지: 00:00+0~30분 무작위 시작, 07:50까지 고르게(최소 30초), 14일 안에 받은 것 제외, 401·403·429·5xx 즉시 중단·재시도 없음, 건수 상한 없음(`REVIEWNOTE_DETAIL_MAX_FETCH` 0, 2026-11-28 결정: 첫 실행이 상한 450이 아니라 목록 제한 때문에 400건 중 41건만 받음). Job 로그 1일 보관, 1건마다 저장 로그, 실행 중 진행 지표(`reviewmaps_scraper_detail_progress_*`) → 대시보드 "지금 상세 수집 진행". 낮에 다시 돌리려면 수동 Job에 `REVIEWNOTE_DETAIL_MANUAL_RUN_MINUTES`(기본 60) 지정. 세션 쿠키는 GSM `prod-reviewmaps-reviewnote-session`(REVIEWNOTE_SESSION, REVIEWNOTE_SESSION_EXPIRES_AT) → ExternalSecret `reviewnote-session`(optional). **약 15일마다 수집 전용 계정으로 재로그인·GSM 갱신 필요**, 만료 3일 전 [WARN] 메일. 절차는 reviewmaps 레포 `claudedocs/reviewnote-travel-selenium.md` |
| 저장 방식 | go-scraper는 DELETE 후 INSERT → `created_at` = 마지막 수집 시각 |
| cleanup | 물리 삭제가 아니라 soft delete (`deleted_at`). DB 조회 시 항상 `deleted_at IS NULL` 조건 |
| cleanup 기준일 | KST 자정 (`cleanup.StartOfDay`). `time.Truncate(24h)`는 UTC 기준이라 사용 금지 |
| 수집 메트릭 | go-scraper가 키워드 시작 시 running=1, 종료 시 결과+running=0을 `PUSHGATEWAY_URL`로 push (`internal/runstats`). grouping 값은 `@base64` 인코딩 (client_golang 기본 인코딩은 공백이 `+`로 저장됨) |
| 서버 /metrics | Fiber 라벨 문자열은 반드시 복사(`strings.Clone`) — zero-copy 버퍼 재사용으로 라벨 손상 시 /metrics 500 |
| GORM AutoMigrate | 운영 비활성 (`DB_AUTO_MIGRATE` 기본 false). Django 제약 이름 불일치 + go-scraper 소유 테이블 변경 위험. 스키마는 `server/migrations/*.sql` |
| DB 직접 조회 | 운영 DB 쓰기 금지. 확인은 Grafana `ReviewMaps-DB` 데이터소스 또는 읽기 전용 임시 Pod (`SET default_transaction_read_only = on`) |
| 수동 실행 | `kubectl -n reviewmaps create job --from=cronjob/<이름> <job이름>`. 수동 Job은 CronJob "마지막 성공 시각"에 반영되지 않음 (Pushgateway 지표에는 반영) |

### Secret / 인증

| 항목 | 내용 |
|------|------|
| External Secrets Operator | v0.9.11, ClusterSecretStore `gcpsm-secret-store`. Secret에만 쓸 수 있고 ConfigMap에는 못 씀 |
| ServerSideApply 앱의 ExternalSecret | ESO 기본값(`conversionStrategy`, `decodingStrategy`, `metadataPolicy`, `deletionPolicy`)을 명시하지 않으면 계속 OutOfSync |
| GSM 시크릿 JSON 형식 | 점이 들어간 평면 키 (`"google.clientId"`), 중첩 객체 아님 |
| Google OAuth 클라이언트 | `yanggo-514212` 프로젝트 웹 클라이언트 (Grafana, ArgoCD Dex 공용). 리디렉션 URI: `monitoring.ggorockee.com/login/generic_oauth`, `argocd.ggorockee.com/api/dex/callback`. 동의 화면 Testing 상태라 Test users만 로그인 가능 |
| 로컬 자격증명 파일 | `.secrets/` (gitignore). 비밀번호·키 위치 목록은 `.secrets/README.md` (공개 저장소라 커밋 금지). 예: `.secrets/oauth-client_yanggo-514212_monitoring-argocd.json` |
| ArgoCD 관리자 | `charts/helm/prod/argo-cd/values.yaml`의 `configs.rbac.policy.csv`에 직접 지정 (ExternalSecret 방식은 ConfigMap 대상이라 동작 안 함) |
| ArgoCD Google 로그인 (Dex) | `dex.config` google 커넥터에 `hostedDomains` 사용 금지. 개인 Gmail 계정은 ID 토큰에 `hd` 클레임이 없어 `oidc: unexpected hd claim`으로 전원 로그인 실패 (#1144에서 제거). 로그인 문제는 `kubectl -n argocd logs deploy/argocd-dex-server`로 확인 |
| ArgoCD 접근 범위 | 도메인 제한 없음. OAuth 동의 화면 Test users만 로그인 가능, `policy.csv` 3개 계정만 admin, 나머지는 `policy.default: role:readonly`. 동의 화면을 Production으로 바꾸면 모든 Google 계정이 readonly 로그인 가능 → 막으려면 `policy.default`를 빈 값으로 |

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

### 앱·광고 운영 메모 (2026-11-27)

| 항목 | 내용 |
|------|------|
| 계정 | AdMob(pub-8516861197467665), Google Ads, Firebase(`reviewmap-c03f1`, `yen-back`, `like-zzix`) 모두 `woohalabs@gmail.com` |
| GA4 | 측정은 어제까지 값만 사용. AdMob 콘솔과 수입이 거의 같음. 라익찍스는 GA4 미연결 → 연결하기로 결정(2026-11-27, 다음 버전) |
| Google Ads | 리뷰맵-안드로이드·리뷰맵-iOS·돌려받엔-iOS 운영 (2026-11-28 돌려받엔 재개, 리뷰맵-iOS 위치는 서울로 남아 있어 확인 필요). 광고비는 비용이 발생하는 항목(하루 예산의 2배까지 쓰일 수 있음)이므로 대시보드 "광고비 · 청구" 행과 Ads* 알림으로 감시. **예산을 바꾸거나 캠페인을 새로 만들면 Secret `monitoring/app-metrics-ads-budget`도 갱신**(방법 `claudedocs/app-metrics-monitoring.md`). 광고비 지표는 `firstUserGoogleAdsCampaignName` 기준 — session 기준은 앱 캠페인에서 0으로 나옴(11-28 수정). 예산 변경은 개발자가 금액을 정한 뒤에만. 예산이 너무 작으면 "운영 가능"이어도 거의 게재되지 않음(2026-11 확인) → 노출·비용이 0이면 예산부터 의심. 전환 액션: 리뷰맵 Android 설치·iOS first_open, 돌려받엔 iOS first_open(GA4 가져오기) |
| AdMob API | 사람 계정 토큰이 Secret `monitoring/app-metrics-admob-oauth`에 있음(GSM·Git 아님, 비용 0 조건). 만료 시 `python3 scripts/admob-oauth-setup.py` 재실행. OAuth 프로젝트는 결제가 꺼진 `yen-back` |
| AdMob 앱 승인 | 스토어 공개 전 앱은 "검토 필요·광고 게재 제한"이 정상 |
| AdMob IDFA 설명 메시지 | 리뷰맵 iOS에 게시(2026-11-27). UMP가 ATT 시스템 창 전에 설명 화면을 띄우므로 앱 업데이트 불필요(2.2.0+는 UMP를 ATT보다 먼저 실행). 표시 수·ATT 동의 비율은 AdMob 개인 정보 보호 및 메시지 > IDFA 설명 |
| AdMob 앱 인증 (신규 공개 앱) | 스토어 연결 직후 "app-ads.txt 확인 불가"로 실패할 수 있음. 파일이 정상이면 크롤링 대기(최대 24시간) 후 "업데이트 확인". App Store 검색은 국가별로 늦게 반영되어 AdMob에서 ID로 안 찾아지면 `https://apps.apple.com/us/app/id<ID>`로 검색 |
| App Store 검색 API 지연 | 출시 직후 `itunes.apple.com/lookup?country=kr`는 몇 시간~하루 늦게 나옴. 수집기 `released`는 이 API에 나온 뒤 바꿔야 AppStoreListingMissing 오탐이 없음 |
| Crashlytics | 리뷰맵 iOS·Android, 돌려받엔 iOS(1.1.1부터, yen-back #20). 돌려받엔 Android는 Firebase에 앱 미등록. 수집기 `crashlytics: true`는 수집이 시작된 뒤에만 |
| 라익찍스 카메라 이벤트 | `camera_permission_denied`(권한 거부) / `camera_failed`(열기 실패) / `camera_unavailable`(카메라 없음, 1.0.0+6 이하는 전부 이 이름). 알림은 권한 거부 제외 (like-zzix #30, infra #1213) |
| 신규 사용자 잔존율 | 수집기가 GA4 코호트로 `app_retention_ratio{day=1|7, source=ads|other}` 수집(8~28일 전 첫 방문). 광고 증액 판단 기준 (#1211) |
| Remote Config 배포 | 각 앱 레포 `firebase/remoteconfig.template.json`이 원본, `firebase deploy --only remoteconfig --project <프로젝트>` |
| 스토어 문구·이미지 (리뷰맵) | 원본 reviewmaps `mobile/store/listing.md`, 촬영·합성 `mobile/tool/`(운영 API 실제 데이터, 이미지는 커밋 안 함), App Store는 `scripts/asc-store.py`(`submit`만 공개로 이어짐). 절차 `claudedocs/app-release-runbook.md` 4-1. Play Console 개발자 계정은 크롬 `u/2` |
| 업데이트 안내 (세 앱 공통, 2026-11-27 결정) | 화면 대부분을 덮는 넘김 카드(최대 3장), 업데이트 전·후. 표준 `claudedocs/app-update-card.md`. 리뷰맵 2.2.3부터, 돌려받엔 1.1.1·라익찍스 다음 버전부터 적용. 릴리스마다 `release_notes.json` 갱신, Remote Config 배포 전 라이브·원본 비교 |
| 리뷰맵 앱 버전 | `mobile/pubspec.yaml`과 `mobile/lib/config/app_version.dart`를 함께 올림 (다르면 테스트 실패, reviewmaps #317) |
| 피클리 카테고리 | 원본 6개 매핑 완료(2026-11-27): 맛집→맛집, 뷰티→뷰티/헬스, 여행→여행, 배송형→쇼핑, 반려동물→반려동물, 서비스→생활서비스 |
| nginx Content-Type | `add_header Content-Type`은 mime.types 값과 합쳐져 `text/plain,text/plain`이 됨 → `types { }` + `default_type` 사용 (#1204) |

### 중지된 서비스

| 서비스 | 중지일 | 상태 | 문서 |
|--------|--------|------|------|
| 오점너 (ojeomneo) | 2026-11-15 | ArgoCD 앱·VirtualService·모니터링 제거, Gemini 키 삭제·API 비활성화·결제 해제. 데이터 보존 (Cloud SQL `ojeomneo` DB, GSM `prod-ojeomneo-*`, Redis PVC, 차트) | `claudedocs/ojeomneo-shutdown.md` (재개 절차 포함) |

- 오점너 Google 자원(Gemini `gen-lang-client-0107981418`, Firebase `ojeomneo-e7f17`)은 `woohalabs@gmail.com` 소유. 기본 gcloud 계정(woohalabs11)은 권한 없음 → `--account=woohalabs@gmail.com`
- woohalabs.com은 app-ads.txt(woohalabs-app-ads)만 서비스, 루트(/)는 404

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
| infra | #1139 | CLAUDE.md 운영 현황 정리 |
| infra | #1140 | 수집 진행률이 첫 키워드 처리 중 비어 보이던 문제 |
| infra | #1141, #1142 | 대시보드 가독성 개선 (짧은 이름, 글자 크기, hh:mm:ss, 단색, 범위표 접기, 패널 높이) |
| infra | #1144 | ArgoCD Google 로그인 실패 수정 (Dex `hostedDomains: gmail.com` 제거) |
| infra | #1146 | 클러스터 전체 모니터링 (blackbox, postgres-exporter, Istio·ArgoCD·ESO·cert-manager·오점너 수집, 규칙 약 50개, 4단계 메일, 클러스터 전체 현황 대시보드) |
| infra | #1147, #1148 | 후속 수정 (Istio 필터 source_* labeldrop 충돌, CPU 계산, 디스크 범위, 비율 0 표시) |
| infra | #1149 | exporter CPU limit 상향 (CPUThrottlingHigh), 문서 마무리 |
| infra | #1161, #1162, #1163 | 오점너 서비스 중지 (모니터링 제거 → ArgoCD 앱 삭제 → VirtualService 비활성화) |
| infra | #1165 | CPU 예약 적정화: 합계 2.33→1.77코어 (노드 1대 1.93 이내, KubeCPUOvercommit 해소), 리뷰맵 서버 limit 100m→500m (11-14 쓰로틀링 88.7%로 키워드 알림 배치 실패), 수집 서버 메일에서 Pushgateway Pod 줄 제거 |
| infra | #1166 | 트래픽 급감·급증 알림에서 Grafana·ArgoCD 제외 (사람 사용량이라 어제 대비 비교 무의미) |
| infra | #1150, #1151 | Cloud SQL 인스턴스 자원 모니터링 (Terraform `modules/monitoring` GSA + Workload Identity, stackdriver-exporter, 알림 `database.cloudsql`), 검증 결과 문서 |
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
- **리뷰맵 하위 차트(`charts/helm/prod/reviewmaps/charts/<이름>/`)를 고치면 `<이름>-<버전>.tgz`도 `helm package charts/<이름> -d charts/`로 다시 만들기**: ArgoCD는 tgz로 렌더링할 수 있음. 2026-11-27 admin tgz가 Nuxt 전환(#1227) 전 템플릿(포트 8000)이라 새 Pod가 헬스체크 실패 (로컬 `helm template`은 디렉터리를 써서 안 보임)
- **모니터링 변경**: 대시보드 색상 기준과 알림 규칙 기준을 함께 변경, 대시보드는 범위표·차트 설명 형식 유지

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
- **Monitoring**: Prometheus, Grafana, SigNoz

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

## 주의사항

- **멀티 클라우드**: AWS와 GCP 개념을 상호 참조하여 설명
- **클라우드 중립적 접근**: 가능한 경우 Kubernetes, Helm 등 클라우드 중립적 솔루션 우선 제안
- **보안**: IAM, Secret 관리 시 각 클라우드의 베스트 프랙티스 준수
- **비용 최적화**: 각 클라우드의 가격 정책 차이 고려
- **Git 워크플로우**: main 브랜치 직접 작업 절대 금지, 항상 feature 브랜치 사용
- **문서 작성**: 프로그래밍 코드 블록 제외, JSON/표 형식만 허용
- **Terraform 문서 동기화**: 리소스 변경 시 TERRAFORM_RESOURCES.md 필수 업데이트

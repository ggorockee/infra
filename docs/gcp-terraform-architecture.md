# GCP Terraform 아키텍처 설계

## 문서 개요

본 문서는 GCP 환경을 Terraform으로 관리하기 위한 아키텍처 설계 및 구현 가이드입니다.

## 프로젝트 폴더 구조 (제안)

```
infra/
├── aws/                           # 기존 AWS 인프라
│   ├── terraform/
│   └── cloudFormation/
├── gcp/                           # 신규 GCP 인프라
│   ├── terraform/
│   │   ├── environments/         # 환경별 설정
│   │   │   ├── dev/
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   ├── outputs.tf
│   │   │   │   └── terraform.tfvars (gitignore)
│   │   │   ├── staging/
│   │   │   │   └── ...
│   │   │   └── prod/
│   │   │       └── ...
│   │   ├── modules/              # 재사용 가능한 모듈
│   │   │   ├── networking/       # VPC, Subnet, Firewall
│   │   │   ├── gke/              # GKE Autopilot 클러스터
│   │   │   ├── cloud-sql/        # Cloud SQL (PostgreSQL)
│   │   │   ├── load-balancer/    # HTTP(S) Load Balancer
│   │   │   ├── dns/              # Cloud DNS
│   │   │   ├── cloud-armor/      # WAF 보안 정책
│   │   │   ├── ssl-certificate/  # Managed SSL 인증서
│   │   │   ├── iam/              # IAM 사용자 및 Service Account
│   │   │   └── storage/          # Cloud Storage
│   │   ├── backend.tf            # Terraform State 백엔드 설정
│   │   └── README.md
│   └── .github/
│       └── workflows/
│           ├── terraform-plan.yml    # PR 시 plan 실행
│           └── terraform-apply.yml   # main 병합 시 apply 실행
├── charts/                        # Kubernetes Helm 차트 (기존)
├── docs/                          # 문서 (본 문서 위치)
└── .github/
    └── workflows/
        ├── gcp-terraform-plan.yml
        └── gcp-terraform-apply.yml
```

## 환경별 디렉토리 구성

각 환경(dev, staging, prod)은 독립적인 Terraform 상태를 가집니다:

**dev/main.tf 예시 구조**
```
module "networking" {
  source = "../../modules/networking"
  environment = "dev"
  ...
}

module "gke" {
  source = "../../modules/gke"
  environment = "dev"
  ...
}
```

## 모듈별 역할

| 모듈 | 설명 | AWS 대응 서비스 |
|------|------|----------------|
| networking | VPC, Subnet, Firewall 규칙 | VPC, Security Groups |
| gke | GKE Autopilot 클러스터 (2CPU 4GiB) | EKS |
| cloud-sql | PostgreSQL 관리형 DB | RDS |
| load-balancer | HTTP(S) Load Balancer + Backend Service | ALB |
| dns | Cloud DNS 설정 | Route 53 |
| cloud-armor | WAF 보안 정책 | AWS WAF |
| ssl-certificate | Google Managed SSL 인증서 (Wildcard) | ACM |
| iam | 사용자 및 Service Account 관리 | IAM |
| storage | Cloud Storage 버킷 | S3 |

## Terraform State 백엔드 설정

**backend.tf 설정**

State 파일을 GCS(Google Cloud Storage)에 저장:

```
terraform {
  backend "gcs" {
    bucket = "your-project-terraform-state"
    prefix = "env/dev"
  }
}
```

**State 백엔드 분리 전략:**
- dev: `gs://terraform-state-bucket/env/dev/`
- staging: `gs://terraform-state-bucket/env/staging/`
- prod: `gs://terraform-state-bucket/env/prod/`

## 컨펌 필요 사항

### 1. 폴더 구조 승인 여부
- 위에 제안한 `gcp/terraform/` 구조로 진행해도 괜찮으신가요?
- 환경 분리(dev/staging/prod)가 필요하신가요, 아니면 dev/prod만 필요하신가요?

### 2. GCP 프로젝트 구성
- GCP 프로젝트는 몇 개로 분리하실 건가요? (환경별 프로젝트 vs 단일 프로젝트)
- 권장: 환경별 분리 (woohalabs-dev, woohalabs-staging, infra)

### 3. Terraform State 백엔드
- GCS 버킷 이름: `woohalabs-terraform-state` 괜찮으신가요?
- State 잠금(locking)을 위한 Cloud Storage 사용 동의하시나요?

### 4. 모듈 구성
- 위에 제안한 모듈 구성에 추가하거나 제외할 항목이 있으신가요?

### 5. CI/CD 도구 선택
- GitHub Actions 사용하시나요? (현재 저장소 기준)
- Terraform Cloud 무료 티어 사용 고려하시나요?

## 다음 단계

컨펌 후 진행할 작업:
1. 폴더 구조 생성
2. 각 모듈별 Terraform 코드 작성
3. CI/CD 파이프라인 구성
4. IAM 설정 및 Service Account 생성
5. 초기 인프라 배포 (dev 환경부터)

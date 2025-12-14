# GCP Terraform 아키텍처 설계

## 문서 개요

본 문서는 GCP 환경을 Terraform으로 관리하기 위한 아키텍처 설계 및 구현 가이드입니다.

## 📊 현재 배포 상태

**Phase 1 완료** (2025-12-14)
- ✅ VPC 네트워킹 (5개 리소스)
- ✅ GKE Autopilot 클러스터 (1개 리소스)
- ⏸️ Phase 2 대기중 (Istio, Cloud SQL, Cloud Armor 등)

**배포된 리소스**:
- VPC Network: `woohalabs-prod-vpc`
- Private Subnet: `woohalabs-prod-private-subnet` (10.0.0.0/24)
- Cloud Router: `woohalabs-prod-router`
- Cloud NAT: `woohalabs-prod-nat`
- Firewall Rule: `woohalabs-prod-allow-internal`
- GKE Autopilot: `woohalabs-prod-gke-cluster` (asia-northeast3)

👉 **상세 리소스 현황**: [TERRAFORM_RESOURCES.md](../gcp/terraform/TERRAFORM_RESOURCES.md)

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

| 모듈 | 설명 | AWS 대응 서비스 | 상태 |
|------|------|----------------|------|
| networking | VPC, Subnet, Firewall 규칙 | VPC, Security Groups | ✅ 배포 완료 |
| gke | GKE Autopilot 클러스터 | EKS | ✅ 배포 완료 |
| cloud-sql | PostgreSQL 관리형 DB | RDS | ⏸️ Phase 3 |
| dns | Cloud DNS 설정 | Route 53 | ⏸️ Phase 2 |
| cloud-armor | WAF 보안 정책 | AWS WAF | ⏸️ Phase 2 |
| ssl-certificate | Google Managed SSL 인증서 | ACM | ⏸️ Phase 2 |
| iam | 사용자 및 Service Account 관리 | IAM | ⏸️ Phase 2 |

**참고**: Istio Ingress Gateway를 통해 Load Balancer 자동 생성 (별도 모듈 불필요)

## Terraform State 백엔드 설정

**backend.tf 설정**

State 파일을 GCS(Google Cloud Storage)에 저장:

**실제 배포된 설정**:
- Bucket: `woohalabs-terraform-state`
- Prefix: `env/prod`
- Project: `infra-480802`
- Object Versioning: 활성화 (State 잠금 및 복구)

**State 백엔드 분리 전략** (향후 환경 추가 시):
- prod: `gs://woohalabs-terraform-state/env/prod/` (현재 사용 중)
- staging: `gs://woohalabs-terraform-state/env/staging/` (미래)
- dev: `gs://woohalabs-terraform-state/env/dev/` (미래)

## 네트워크 아키텍처

### VPC 구성 (현재 배포됨)

**VPC**: `woohalabs-prod-vpc`
- Auto-create subnetworks: 비활성화 (수동 관리)
- Region: asia-northeast3 (서울)

**Subnet**: `woohalabs-prod-private-subnet`
- Primary CIDR: 10.0.0.0/24 (256 IPs)
- Pods Range: 10.1.0.0/16 (GKE Pod IP)
- Services Range: 10.2.0.0/16 (GKE Service IP)
- Private Google Access: 활성화

**Cloud NAT**: `woohalabs-prod-nat`
- 목적: Private Subnet 아웃바운드 인터넷 접근
- 비용: 월 $35-40
- 로깅: ERRORS_ONLY

**Firewall**: `woohalabs-prod-allow-internal`
- 허용 프로토콜: TCP (0-65535), UDP (0-65535), ICMP
- Source Range: 10.0.0.0/24 (내부 통신만)

### GKE 클러스터 구성 (현재 배포됨)

**클러스터**: `woohalabs-prod-gke-cluster`
- 모드: Autopilot (완전 관리형)
- Region: asia-northeast3 (Multi-AZ)
- Release Channel: REGULAR
- Maintenance Window: 03:00 UTC (12:00 KST)
- Network: woohalabs-prod-vpc
- Subnet: woohalabs-prod-private-subnet

### Ingress 전략 (Phase 2 예정)

**Istio 서비스 메시**:
- Istio Ingress Gateway를 통한 트래픽 라우팅
- Kubernetes 네이티브 Ingress 대체
- Cloud Armor 연동 (WAF)
- Multi-domain 라우팅 지원
- Path 기반 라우팅 (`/api/*`, `/admin/*`)

**Load Balancer**: Istio Gateway가 자동 생성 (별도 Terraform 모듈 불필요)

## CI/CD 파이프라인 (현재 배포됨)

### GitHub Actions GitOps 워크플로우

**gcp-terraform-plan.yml**:
- 트리거: Pull Request 생성/업데이트
- 동작: terraform init → plan
- 결과: PR 코멘트로 Plan 출력

**gcp-terraform-apply.yml**:
- 트리거: main 브랜치 푸시 (PR 머지 후)
- 동작: terraform init → plan → apply
- 결과: GitHub Actions Summary

**GitOps 패턴**:
1. Feature 브랜치 생성
2. Terraform 코드 수정
3. PR 생성 → 자동 Plan 실행
4. Plan 검토 후 Squash and Merge
5. main 브랜치 푸시 → 자동 Apply 실행

## 다음 Phase 계획

**Phase 2**: Istio 서비스 메시 및 보안
- Istio 배포 (Helm)
- Istio Ingress Gateway 설정
- Cloud Armor WAF 연동
- Cloud DNS 설정
- SSL 인증서 프로비저닝

**Phase 3**: 데이터베이스 마이그레이션
- Cloud SQL PostgreSQL 생성
- Private IP 설정
- 데이터 마이그레이션

**Phase 4**: 워크로드 마이그레이션
- 애플리케이션 배포
- HPA 설정
- 비용 검증

**Phase 5**: DNS 전환
- Istio Ingress Gateway External IP 확보
- Cloud DNS 레코드 설정
- 트래픽 전환

**Phase 6**: 최종 정리
- 모니터링 대시보드
- AWS 리소스 정리

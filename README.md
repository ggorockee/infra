# Infrastructure as Code

GCP 기반 Kubernetes 인프라 관리 저장소

## 📊 현재 배포 상태

### GCP Production 환경 (2025-12-14 기준)

| Phase | 컴포넌트 | 상태 | 비고 |
|-------|---------|------|------|
| **Phase 1** | VPC 네트워킹 | ✅ 완료 | asia-northeast3 |
| | GKE Autopilot | ✅ 완료 | woohalabs-prod-gke-cluster |
| **Phase 2** | External Secrets | ✅ 완료 | GCP Secret Manager 연동 |
| | ClusterSecretStore | ✅ 완료 | Workload Identity |
| **Phase 3** | ArgoCD | ✅ 완료 | Google OAuth 인증 |
| | ApplicationSet | ✅ 완료 | GitOps 자동 배포 |
| **Phase 4** | Istio Service Mesh | ✅ 완료 | v1.28.1 |
| | istio-ingressgateway | ✅ 완료 | LB: 34.50.12.202 |

## 프로젝트 구조

```
infra/
├── gcp/
│   └── terraform/              # GCP Terraform 모듈
│       ├── environments/prod/  # Production 환경
│       ├── modules/
│       │   ├── networking/     # VPC, Subnet
│       │   ├── gke/            # GKE Autopilot
│       │   ├── external-secrets/  # External Secrets Operator
│       │   └── argocd/         # ArgoCD GitOps
│       └── README.md
│
├── charts/
│   └── helm/
│       └── prod/
│           ├── istio-system/   # Istio 서비스 메시
│           │   ├── istio-base/
│           │   ├── istiod/
│           │   └── istio-ingressgateway/
│           ├── ojeomneo/       # Ojeomneo 애플리케이션
│           └── reviewmaps/     # ReviewMaps 애플리케이션
│
├── argocd_yaml/
│   └── prod-applicationsets-gitchart.yaml  # ApplicationSet
│
└── docs/                       # 문서
    ├── gcp-terraform-architecture.md
    ├── gcp-istio-deployment.md
    └── ...
```

## 주요 기술 스택

### Infrastructure
- **IaC**: Terraform (v1.5.0+)
- **클라우드**: Google Cloud Platform
- **컨테이너 오케스트레이션**: GKE Autopilot
- **GitOps**: ArgoCD
- **서비스 메시**: Istio v1.28.1

### 보안 & 인증
- **Secret 관리**: External Secrets Operator + GCP Secret Manager
- **인증**: Workload Identity (GKE ↔ GCP)
- **OAuth**: Google OAuth (ArgoCD)

### 배포 자동화
- **CI/CD**: GitHub Actions
- **Helm**: 패키지 관리
- **ArgoCD**: GitOps 자동 동기화

## 빠른 시작

### 1. Terraform으로 GCP 인프라 배포

```bash
cd gcp/terraform/environments/prod
terraform init
terraform plan
terraform apply
```

### 2. ArgoCD 접속

**URL**: http://34.47.88.233

**인증 방식**:
- Google OAuth (woohaen88@gmail.com, woohalabs@gmail.com, ggorockee@gmail.com)
- 또는 admin 계정

### 3. Istio Ingress Gateway

**External IP**: 34.50.12.202

**포트**:
- HTTP: 80
- HTTPS: 443
- Metrics: 15021

## 문서

### GCP Terraform
- [Terraform Architecture](./gcp/terraform/README.md)
- [Terraform Resources](./gcp/terraform/TERRAFORM_RESOURCES.md)

### 가이드
- [Istio Deployment Guide](./docs/gcp-istio-deployment.md)
- [IAM Strategy](./docs/gcp-iam-strategy.md)
- [CI/CD Pipeline](./docs/gcp-cicd-pipeline.md)

## Git 워크플로우

### 브랜치 전략

- **main**: Production 배포 브랜치 (보호됨)
- **feature/\***: 기능 개발 브랜치
- **fix/\***: 버그 수정 브랜치

### PR 규칙

1. main 브랜치 직접 push 금지
2. Feature 브랜치에서 작업
3. PR 생성 및 리뷰
4. Squash and Merge 사용
5. PR 머지 후 feature 브랜치 삭제

### Commit Convention

```
feat: 새 기능 추가
fix: 버그 수정
docs: 문서 수정
chore: 설정 변경
refactor: 코드 리팩토링
```

## 주요 링크

- **GCP Console**: https://console.cloud.google.com/
- **ArgoCD**: http://34.47.88.233
- **Istio Gateway**: http://34.50.12.202
- **GitHub**: https://github.com/ggorockee/infra

## 비용 관리

- **예산**: $130/month
- **현재 추정**: ~$90-125/month
- **주요 비용**:
  - GKE Autopilot 클러스터
  - Cloud Load Balancer (Istio Ingress)
  - Networking (Egress)

## 지원

문제 발생 시:
1. GitHub Issues 생성
2. ArgoCD UI에서 Application 상태 확인
3. `kubectl get pods -A` 로 파드 상태 확인
4. Istio 관련: [Istio Troubleshooting](https://istio.io/latest/docs/ops/common-problems/)

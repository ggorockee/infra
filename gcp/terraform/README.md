# GCP Terraform Infrastructure

GCP 인프라를 코드로 관리하기 위한 Terraform 설정입니다.

## 📊 현재 배포 상태

**Phase 1 완료** (2025-12-14)
- ✅ VPC 네트워킹 (5개 리소스)
- ✅ GKE Autopilot 클러스터 (1개 리소스)
- ⏸️ Phase 2 대기중 (Cloud SQL, Load Balancer 등)

👉 **상세 리소스 현황**: [TERRAFORM_RESOURCES.md](./TERRAFORM_RESOURCES.md)

## 프로젝트 정보

- **프로젝트 ID**: infra-480802
- **Region**: asia-northeast3 (서울)
- **환경**: Production (단일 환경)
- **도메인**: woohalabs.com
- **예산**: $130/month
- **현재 비용**: ~$90-125/month (예상)

## 폴더 구조

| 폴더 | 상태 | 설명 |
|------|------|------|
| `environments/prod/` | ✅ Active | Production 환경 Terraform 코드 |
| `modules/networking/` | ✅ Active | VPC, Subnet, Firewall 모듈 |
| `modules/gke/` | ✅ Active | GKE Autopilot 클러스터 모듈 |
| `modules/cloud-sql/` | ⏸️ Pending | Cloud SQL PostgreSQL 모듈 |
| `modules/load-balancer/` | ⏸️ Pending | HTTP(S) Load Balancer 모듈 |
| `modules/dns/` | ⏸️ Pending | Cloud DNS 모듈 |
| `modules/cloud-armor/` | ⏸️ Pending | WAF 보안 정책 모듈 |
| `modules/ssl-certificate/` | ⏸️ Pending | Managed SSL 인증서 모듈 |
| `modules/iam/` | ⏸️ Pending | IAM 사용자 및 Service Account 모듈 |
| `modules/external-secrets/` | ⏸️ Pending | External Secrets Operator 모듈 |

## Terraform State 백엔드

- **버킷**: `woohalabs-terraform-state`
- **Region**: asia-northeast3
- **Versioning**: 활성화
- **State 경로**: `gs://woohalabs-terraform-state/env/prod/`

## 사전 요구사항

1. **Google Cloud SDK 설치**
   - gcloud CLI 인증 완료

2. **Terraform 설치**
   - Version: >= 1.5.0

3. **GitHub Secrets 설정**
   - `GCP_PROJECT_ID`: infra-480802
   - `GCP_SA_KEY`: Service Account Key JSON
   - `TF_STATE_BUCKET`: woohalabs-terraform-state

## 사용 방법

### 초기 설정

1. **GCS State 백엔드 버킷 생성** (최초 1회만)
2. **Terraform 초기화**
3. **Plan 실행**
4. **Apply 실행**

### CI/CD

GitHub Actions를 통한 자동 배포:
- **Plan**: Pull Request 생성 시 자동 실행
- **Apply**: main 브랜치 머지 시 자동 실행

## 모듈별 설명

### External Secrets Operator

GCP Secret Manager와 Kubernetes Secret 동기화:
- Secret Manager에서 민감 정보 중앙 관리
- Kubernetes에서 ExternalSecret CRD로 자동 동기화
- 비밀번호 로테이션 자동화
- IAM 기반 접근 제어

### 기타 모듈

각 모듈의 상세 설명은 해당 모듈 디렉토리의 README 참조

## 📝 리소스 네이밍 컨벤션

모든 GCP 리소스는 다음 네이밍 패턴을 따릅니다:

```
woohalabs-{environment}-{resource-type}
```

**예시**:
- VPC: `woohalabs-prod-vpc`
- GKE: `woohalabs-prod-gke-cluster`
- Subnet: `woohalabs-prod-private-subnet`

## 주의사항

- **State 파일 보안**: State 파일에는 민감 정보 포함
- **변경 전 Plan 확인**: 항상 plan 결과 확인 후 apply
- **main 브랜치 보호**: 직접 push 금지, PR 필수
- **리소스 문서 동기화**: Terraform 변경 시 `TERRAFORM_RESOURCES.md` 반드시 업데이트

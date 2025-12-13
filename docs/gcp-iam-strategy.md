# GCP IAM 전략 및 보안 설정

## IAM 기본 원칙

### AWS IAM과의 비교

| AWS IAM | GCP IAM | 설명 |
|---------|---------|------|
| Root Account | Organization Admin | 최상위 관리자 계정 |
| IAM User | User Account | 개별 사용자 계정 |
| IAM Role | Service Account | 애플리케이션/서비스 인증 |
| Policy | IAM Policy Binding | 권한 부여 방식 |
| Access Key | Service Account Key (JSON) | 프로그래밍 방식 인증 |

## Root Email 사용 자제 전략

### 문제점
- Root email은 조직의 모든 권한 보유
- 단일 실패 지점(Single Point of Failure)
- 감사 추적 어려움
- 권한 분리 원칙 위반

### 권장 구조

**Organization 계층**:
```
Organization (root email로 생성, 이후 사용 자제)
├── Folder: Production
│   └── Project: infra
├── Folder: Staging
│   └── Project: woohalabs-staging
└── Folder: Development
    └── Project: woohalabs-dev
```

**사용자 역할 분리**:

| 역할 | 계정 타입 | 권한 범위 | 예시 |
|-----|---------|----------|------|
| Organization Admin | User Account | 조직 전체 | admin@woohalabs.com (긴급용) |
| Project Owner | User Account | 프로젝트별 | woohyeon@woohalabs.com |
| Developer | User Account | 개발 환경 | dev1@woohalabs.com |
| CI/CD | Service Account | 자동화 전용 | terraform@infra.iam.gserviceaccount.com |
| Application | Service Account | 런타임 | app-server@infra.iam.gserviceaccount.com |

## 사용자별 계정 생성 전략

### 1. Google Workspace 또는 Cloud Identity 사용

**권장 방식**: Google Workspace (구 G Suite) 또는 Cloud Identity

**장점**:
- 중앙화된 사용자 관리
- SSO (Single Sign-On) 지원
- 2FA (Two-Factor Authentication) 강제
- 사용자 계정 생명주기 관리

**비용**:
- Cloud Identity Free: 무료 (기본 기능)
- Google Workspace Business Starter: $6/user/month

### 2. 개별 사용자 계정 구성

**각 개발자별 계정 생성**:
- `woohyeon@woohalabs.com`
- `developer1@woohalabs.com`
- `developer2@woohalabs.com`

**권한 부여 원칙**:
- 최소 권한 원칙 (Principle of Least Privilege)
- 환경별 권한 분리 (dev는 dev만, prod는 승인된 사용자만)
- 시간 제한 권한 (Just-In-Time Access)

### 3. Service Account 전략

**Terraform용 Service Account**:
- 이름: `terraform-automation@project.iam.gserviceaccount.com`
- 권한: Editor 또는 커스텀 Terraform 역할
- Key 관리: GitHub Secrets에 안전하게 저장

**애플리케이션용 Service Account**:
- GKE Workload Identity 사용 (Key 파일 불필요)
- 각 서비스별 별도 Service Account
- 최소 권한만 부여

## IAM Policy 설정 예시

### 사용자 역할별 권한

**개발자 (Development 환경)**:
- Kubernetes Engine Developer
- Cloud SQL Client
- Storage Object Viewer
- Logging Viewer

**DevOps 엔지니어 (Production 환경)**:
- Kubernetes Engine Admin
- Cloud SQL Admin
- Storage Admin
- Logging Admin

**읽기 전용 사용자**:
- Viewer (기본 역할)
- Kubernetes Engine Viewer
- Cloud SQL Viewer

### Terraform Service Account 권한

**필요한 역할**:
- Compute Admin (GKE, Load Balancer)
- Kubernetes Engine Admin
- Cloud SQL Admin
- DNS Administrator
- Security Admin (Cloud Armor)
- Service Account Admin
- Storage Admin (Terraform State)

## 보안 모범 사례

### 1. Root Email 보호
- 강력한 비밀번호 + 2FA 필수
- 일상 작업에 사용 금지
- 비상 복구 시에만 사용
- 감사 로그 모니터링

### 2. Service Account Key 관리
- Key 파일을 Git에 절대 커밋 금지
- Key Rotation 정기적 수행 (90일마다)
- Workload Identity 사용으로 Key 파일 최소화
- 사용하지 않는 Key 즉시 삭제

### 3. 권한 감사
- IAM Recommender 활용 (과도한 권한 탐지)
- 주기적인 권한 리뷰 (분기별)
- Cloud Audit Logs 활성화
- Alerting 설정 (비정상 접근 탐지)

### 4. 네트워크 보안
- VPC Service Controls 사용
- Private GKE Cluster 구성
- Cloud NAT로 아웃바운드 트래픽 제어
- Firewall Rules 최소화

## Terraform으로 IAM 관리

### Service Account 생성 모듈

**modules/iam/service-accounts.tf 구조**:
- `google_service_account`: Service Account 생성
- `google_project_iam_member`: 프로젝트 레벨 권한 부여
- `google_service_account_key`: Key 생성 (필요시)

### User Account 권한 부여

**modules/iam/users.tf 구조**:
- `google_project_iam_member`: 사용자별 역할 부여
- 환경별 분리 (dev/staging/prod)

## 초기 설정 체크리스트

- [ ] Google Workspace 또는 Cloud Identity 설정
- [ ] Organization 구성 및 Folder 생성
- [ ] Root email에 2FA 활성화
- [ ] 개발자별 개인 계정 생성
- [ ] Terraform용 Service Account 생성 및 Key 발급
- [ ] Service Account Key를 GitHub Secrets에 저장
- [ ] IAM 정책 코드로 관리 (Terraform)
- [ ] Cloud Audit Logs 활성화
- [ ] IAM Recommender 검토 설정

## 일상 운영 가이드

### 신규 개발자 추가 시
1. Google Workspace에서 계정 생성
2. 적절한 IAM 역할 부여 (Terraform 코드 수정)
3. `terraform apply`로 권한 적용
4. 2FA 활성화 확인

### 개발자 퇴사 시
1. Google Workspace에서 계정 비활성화
2. IAM 역할 제거 (Terraform 코드 수정)
3. 해당 사용자의 Service Account Key 삭제
4. Audit Log 확인

### 긴급 권한 부여
1. Just-In-Time Access 요청
2. 시간 제한 권한 부여 (예: 4시간)
3. 작업 완료 후 자동 권한 회수
4. Audit Log 리뷰

## 비용 최적화

**무료로 사용 가능**:
- Cloud Identity Free (기본 SSO, 사용자 관리)
- Service Account (무제한 무료)
- IAM Policy (무료)

**유료 고려사항**:
- Google Workspace: $6/user/month (이메일, 드라이브 포함)
- Cloud Identity Premium: $6/user/month (고급 보안 기능)

**권장 시작점**:
- 5명 이하: Cloud Identity Free
- 5명 이상: Google Workspace Business Starter

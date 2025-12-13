# GCP Terraform 인프라 설계 문서

## 문서 목록

본 디렉토리는 GCP 환경을 Terraform으로 관리하기 위한 전체 설계 문서를 포함합니다.

### 📋 핵심 문서

| 문서 | 설명 | 주요 내용 |
|-----|------|---------|
| [gcp-terraform-architecture.md](gcp-terraform-architecture.md) | 전체 아키텍처 설계 | 폴더 구조, 모듈 구성, 컨펌 사항 |
| [gcp-aws-service-mapping.md](gcp-aws-service-mapping.md) | AWS ↔ GCP 서비스 매핑 | Route53+ALB+WAF+ACM의 GCP 전환 |
| [gcp-iam-strategy.md](gcp-iam-strategy.md) | IAM 보안 전략 | Root email 사용 자제, 사용자별 권한 |
| [gcp-database-strategy.md](gcp-database-strategy.md) | 데이터베이스 전략 | Cloud SQL vs 로컬 VM 비용 분석 |
| [gcp-gke-autopilot-strategy.md](gcp-gke-autopilot-strategy.md) | GKE Autopilot 최적화 | 2CPU 4GiB 비용 최적화, 업그레이드 전략 |
| [gcp-cicd-pipeline.md](gcp-cicd-pipeline.md) | CI/CD 파이프라인 | Terraform Plan/Apply 자동화 |

## 빠른 참조

### 주요 의사결정 사항

#### 1. 폴더 구조
- 제안: `gcp/terraform/environments/{dev,staging,prod}` + `modules/`
- 컨펌 필요: 환경 분리 전략 (dev/prod vs dev/staging/prod)

#### 2. AWS → GCP 서비스 전환

| AWS | GCP |
|-----|-----|
| Route 53 | Cloud DNS |
| ALB | HTTP(S) Load Balancer |
| ACM | Google-managed SSL Certificates |
| WAF | Cloud Armor |
| EKS | GKE Autopilot |
| RDS | Cloud SQL |

#### 3. 데이터베이스 선택

**현재 데이터**: 5~7만건, 일 4천건 업데이트

**권장 옵션**:
- 비용 우선: 로컬 VM 유지 ($30/월)
- 균형 추천: 하이브리드 (dev: 로컬, prod: Cloud SQL db-g1-small) ($65/월)
- 안정성 우선: 완전 Cloud SQL ($190/월)

#### 4. GKE Autopilot 비용 최적화

**목표**: 2 CPU, 4GiB 설정

**예상 비용**:
- Pod 1개 (2 CPU, 4GiB): $79/월
- 일반 워크로드 (4 Pods, HPA 포함): $80~120/월

**AWS EKS 대비**: 약 20% 절감

#### 5. CI/CD 파이프라인

**워크플로우**:
```
PR 생성 → terraform plan → 리뷰 → main 병합 → terraform apply
```

**도구**: GitHub Actions (무료 범위 내)

## 구현 로드맵

### Phase 1: 기반 구축 (1~2주)
- [ ] 폴더 구조 생성
- [ ] GCS State 백엔드 설정
- [ ] Service Account 및 IAM 구성
- [ ] Terraform 모듈 작성 (networking, iam)

### Phase 2: 네트워크 및 보안 (2~3주)
- [ ] VPC 및 Subnet 구성
- [ ] Cloud Armor WAF 설정
- [ ] Cloud DNS 설정
- [ ] SSL 인증서 프로비저닝

### Phase 3: 컴퓨팅 (3~4주)
- [ ] GKE Autopilot 클러스터 생성
- [ ] Load Balancer 및 Backend Service 설정
- [ ] URL Map 라우팅 구성

### Phase 4: 데이터베이스 (4~5주)
- [ ] Cloud SQL vs 로컬 VM 최종 결정
- [ ] Cloud SQL 인스턴스 생성 (선택 시)
- [ ] 데이터 마이그레이션 (선택 시)

### Phase 5: CI/CD 자동화 (5~6주)
- [ ] GitHub Actions 워크플로우 작성
- [ ] Plan/Apply 자동화 테스트
- [ ] Slack/Discord 알림 설정

### Phase 6: 모니터링 및 최적화 (6~7주)
- [ ] Cloud Monitoring 설정
- [ ] Budget Alerts 구성
- [ ] 비용 최적화 검토

## 컨펌 필요 사항 요약

### 1. 아키텍처
- [ ] 폴더 구조 승인 (`gcp/terraform/environments/` + `modules/`)
- [ ] 환경 분리 전략 (dev/staging/prod vs dev/prod)
- [ ] GCP 프로젝트 구성 (환경별 분리 vs 단일 프로젝트)

### 2. 데이터베이스
- [ ] Cloud SQL vs 로컬 VM 선택
- [ ] Cloud SQL 선택 시 스펙 (db-g1-small vs db-custom-2-4096)
- [ ] 다운타임 허용 시간

### 3. GKE Autopilot
- [ ] 예상 워크로드 (서비스 개수, Pod 수)
- [ ] 트래픽 패턴 (평시 vs 피크)
- [ ] 개발 환경 자동 종료 허용 여부

### 4. CI/CD
- [ ] GitHub Actions vs Terraform Cloud
- [ ] Production 자동 Apply 허용 여부
- [ ] 알림 도구 (Slack, Discord, Email)

### 5. 예산
- [ ] 월 예산 상한선
- [ ] 비용 vs 안정성 우선순위

## 다음 단계

1. **위 컨펌 사항에 대한 의사결정**
2. **Phase 1 시작**: 폴더 구조 및 기본 모듈 생성
3. **각 문서 상세 검토** 및 질문 사항 정리
4. **우선순위 결정**: 어떤 부분부터 구현할지 결정

## 추가 리소스

### GCP 공식 문서
- Terraform Provider: https://registry.terraform.io/providers/hashicorp/google/latest/docs
- GKE Autopilot: https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview
- Cloud SQL: https://cloud.google.com/sql/docs

### 비용 계산기
- GCP Pricing Calculator: https://cloud.google.com/products/calculator

### 커뮤니티
- GCP Terraform 모듈: https://github.com/terraform-google-modules

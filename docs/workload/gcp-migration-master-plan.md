# GCP 마이그레이션 종합 계획서

## 프로젝트 개요

**목표**: AWS에서 GCP로 전환하면서 Terraform으로 인프라 코드화 및 CI/CD 자동화 구축

**현재 상황**:
- 소규모 1인 개발 환경
- 개발 인프라 없음 (프로덕션만 존재)
- 현재 앱 서비스: 2개 운영 중
- 향후 계획: 서비스 계속 추가 예정
- **비용 최소화 필수**: 단일 환경으로 모든 비용 절감

**예산 제약**:
- GKE: 월 10만원 ($75) 상한
- Cloud SQL: 월 $30 (db-g1-small, Private IP)
- 기타 인프라: 월 $25 (LB, DNS, Storage, Armor)
- **총 인프라 예산: 월 $130 목표**

**기간**: 4~5주 (Phase 1~4, 개발 환경 제외로 단축)

## 마이그레이션 우선순위

| 순서 | 컴포넌트 | 현재 (AWS) | 목표 (GCP) | 우선순위 | 이유 |
|-----|---------|-----------|-----------|---------|-----|
| 1 | Database | K8s 내부 VM PostgreSQL | Cloud SQL Private IP | 🔴 Critical | 브루트 포스 공격 대응 |
| 2 | CI/CD | 수동 | GitHub Actions + Terraform | 🔴 Critical | 자동화 기반 마련 |
| 3 | Networking | Route53 + ALB + WAF | Cloud DNS + LB + Cloud Armor | 🟡 High | 트래픽 라우팅 |
| 4 | Compute | EKS | GKE Autopilot | 🟡 High | 워크로드 실행 환경 |
| 5 | Monitoring | CloudWatch | Cloud Monitoring | 🟢 Medium | 관찰성 확보 |

## Phase별 마이그레이션 계획

### Phase 1: 기반 구축 및 네트워킹 (1주차) ✅ **완료** (2025-12-14)

**목표**: Terraform 환경 및 GCP 프로젝트 초기 설정, VPC 네트워킹 및 GKE 클러스터 배포

#### 1.1 GCP 프로젝트 설정
- [x] GCP Organization 생성 또는 확인
- [x] 프로젝트 생성 (infra-480802 단일 환경)
- [x] Billing Account 연결
- [x] Budget Alert 설정 (GKE $75, Cloud SQL $30, 총 $130)
- [x] GKE API 활성화

#### 1.2 IAM 설정
- [ ] Root email에 2FA 활성화
- [ ] 개인 개발자 계정 생성 (1인, Cloud Identity Free)
- [x] Terraform용 Service Account 생성
- [x] Service Account Key 발급 및 GitHub Secrets 저장
- [x] IAM 역할 부여 (Editor, Storage Admin, Security Admin)

#### 1.3 Terraform 폴더 구조 생성
- [x] `gcp/terraform/` 폴더 생성
- [x] 환경 폴더: `environments/prod/` (단일 환경)
- [x] 모듈 폴더: `modules/networking/`, `modules/gke/`, `modules/cloud-sql/`, `modules/iam/`, `modules/external-secrets/`
- [x] GCS State 백엔드 버킷 생성 (`woohalabs-terraform-state`)
- [x] State 잠금 활성화 확인 (Object Versioning 활성화)

#### 1.4 GitHub Actions GitOps 워크플로우 설정
- [x] `.github/workflows/` 폴더 생성
- [x] `gcp-terraform-plan.yml` 워크플로우 작성 (PR 생성 시 Plan)
- [x] `gcp-terraform-apply.yml` 워크플로우 작성 (main 푸시 시 Apply)
- [x] GitHub Secrets 설정 확인 (GCP_PROJECT_ID, GCP_SA_KEY)
- [x] GitOps 패턴 구현 (PR → Plan → Squash Merge → Apply)

#### 1.5 VPC 네트워킹 배포 (비용 최적화로 변경)
- [x] **Default VPC 사용** (Custom VPC 대신 비용 절감)
  - 네트워킹 비용: $56/월 → $0/월 절감
  - Cloud Router 제거
  - Cloud NAT 제거

#### 1.6 GKE Standard 클러스터 배포 (비용 최적화로 변경)
- [x] **GKE Standard + Spot Instance** 클러스터 생성 (`woohalabs-prod-gke-cluster`)
  - 모드: Standard (Autopilot 대신 Spot Instance 지원)
  - Zone: asia-northeast3-a (Single Zone, Free Tier)
  - Release Channel: REGULAR
  - Network: default
  - Subnet: default
  - **Node Pool**: woohalabs-prod-spot-pool
    - Machine Type: e2-medium (2 vCPU, 4GB RAM)
    - Spot Instance: 활성화 (91% 비용 절감)
    - Node Count: 1 (초기)
    - Auto-scaling: 1-3 nodes
  - **고가용성**: 리소스 부족 시 자동 노드 확장

#### 1.7 External Secrets Operator 배포
- [x] Terraform 모듈 작성 완료
- [ ] 배포 대기 중 (PR #632 머지 후)

**배포 완료 리소스** (3개):
- Default VPC Network (기존 사용)
- Default Subnet (기존 사용)
- GKE Standard Cluster: woohalabs-prod-gke-cluster
- Node Pool: woohalabs-prod-spot-pool (Spot Instance)

**완료 기준**: 🔄 **진행 중 (PR #632)**
- [x] Terraform init 성공
- [x] GitHub Actions에서 plan 실행 확인
- [x] State가 GCS에 저장됨
- [x] Default VPC 활용 (비용 최적화)
- [x] GKE Standard + Spot Instance 설정 완료
- [x] Node Auto-scaling 설정 (1-3 nodes)
- [ ] Terraform Plan 성공 대기
- [ ] PR #632 머지 후 배포 완료
- [ ] External Secrets Operator 정상 작동 확인

---

### Phase 2: Istio 서비스 메시 및 보안 (2주차)

**목표**: Istio 배포, Ingress Gateway 설정, Cloud Armor, Cloud DNS 구성

#### 2.1 Istio 서비스 메시 배포
- [ ] Istio 설치 (istioctl 또는 Helm) -- Helm
- [ ] Istio Ingress Gateway 배포
- [ ] Gateway 리소스 생성 (HTTP/HTTPS 트래픽 라우팅)
- [ ] VirtualService 설정 (경로 기반 라우팅)
- [ ] DestinationRule 설정 (로드 밸런싱, Circuit Breaking)

#### 2.2 Istio Ingress 트래픽 관리
- [ ] 기존 Kubernetes Ingress를 Istio Gateway로 전환
- [ ] Multi-domain 라우팅 설정
- [ ] Path 기반 라우팅 설정 (`/api/*`, `/admin/*`)
- [ ] HTTPS 리다이렉트 설정

#### 2.3 Cloud Armor WAF 설정 (Istio Ingress Gateway 연동)
- [ ] Security Policy 생성
- [ ] Rate Limiting 규칙 (브루트 포스 방지)
- [ ] Geo-blocking 설정 (필요 시)
- [ ] OWASP Top 10 기본 룰셋 적용
- [ ] Istio Ingress Gateway와 Cloud Armor 연동

#### 2.4 Cloud DNS 설정
- [ ] Cloud DNS Zone 생성 (woohalabs.com)
- [ ] Route53에서 DNS 레코드 확인
- [ ] NS 레코드 마이그레이션 준비 (도메인 레지스트라 업데이트 대기)

#### 2.5 SSL 인증서 프로비저닝
- [ ] Google-managed SSL Certificate 생성
- [ ] 도메인 소유권 확인
- [ ] Certificate Map 생성 (Multi-domain 지원)
- [ ] Istio Gateway에 SSL 인증서 연결

**완료 기준**:
- Istio 서비스 메시 정상 작동
- Istio Ingress Gateway로 트래픽 라우팅 성공
- Cloud Armor 정책 활성화
- DNS Zone 생성 완료 (실제 전환은 Phase 5 이후)

---

### Phase 3: 데이터베이스 마이그레이션 (3주차)

**목표**: K8s 내부 VM PostgreSQL → Cloud SQL Private IP 이전

#### 3.1 Cloud SQL 인스턴스 생성
- [ ] Cloud SQL PostgreSQL 인스턴스 생성
  - [ ] 스펙: db-g1-small (1 vCPU, 1.7GB RAM)
  - [ ] 버전: PostgreSQL 14 또는 15
  - [ ] Private IP 설정 (VPC 연결)
  - [ ] Public IP 비활성화
- [ ] 자동 백업 설정 (매일 새벽 3시)
- [ ] High Availability 설정 (선택 사항, 비용 추가)

#### 3.2 보안 설정
- [ ] IAM Database Authentication 활성화
- [ ] VPC Service Controls 적용
- [ ] Cloud Armor 연동 (Proxy 경유 시)
- [ ] Cloud Audit Logs 활성화

#### 3.3 데이터 마이그레이션
- [ ] 현재 DB 백업 생성 (pg_dump)
- [ ] Cloud SQL로 데이터 복원 (pg_restore)
- [ ] 데이터 무결성 검증 (레코드 개수, 샘플 데이터)
- [ ] 읽기 전용 모드로 병렬 운영 테스트

#### 3.4 애플리케이션 연결 변경
- [ ] 애플리케이션 DB 연결 문자열 업데이트 (Private IP)
- [ ] Connection Pooling 설정 (PgBouncer 또는 Cloud SQL Proxy)
- [ ] 환경 변수 업데이트 (K8s Secret)
- [ ] 롤아웃 및 헬스 체크 확인

#### 3.5 구 VM 정리
- [ ] 24시간 모니터링 (에러 없음 확인)
- [ ] 최종 백업 생성 및 Cloud Storage 보관
- [ ] K8s 내부 VM PostgreSQL Pod 삭제
- [ ] 관련 PV/PVC 정리

**완료 기준**:
- Cloud SQL 정상 운영 확인 (24시간)
- 브루트 포스 공격 차단 확인
- 애플리케이션 에러율 0%
- 구 VM 완전 제거

---

### Phase 4: 워크로드 마이그레이션 (4주차)

**목표**: GKE Autopilot 클러스터로 애플리케이션 워크로드 이전 (예산: $75/월)

**참고**: GKE 클러스터는 Phase 1에서 이미 배포 완료 (`woohalabs-prod-gke-cluster`)

#### 4.1 워크로드 리소스 최적화 (앱 서비스 2개)
- [ ] 앱 서비스 1 Deployment 작성
  - [ ] requests: 500m CPU, 1Gi RAM
  - [ ] limits: 1000m CPU, 2Gi RAM
  - [ ] HPA: min 1, max 3 (CPU 70%)
  - [ ] 평시 비용: $20/월, 피크 비용: $60/월
- [ ] 앱 서비스 2 Deployment 작성
  - [ ] requests: 250m CPU, 512Mi RAM
  - [ ] limits: 500m CPU, 1Gi RAM
  - [ ] Replicas: 1 (고정)
  - [ ] 비용: $10/월
- [ ] Worker CronJob 작성 (필요 시)
  - [ ] requests: 500m CPU, 1Gi RAM
  - [ ] schedule: "0 2 * * *" (매일 새벽 2시)
  - [ ] 비용: ~$3/월
- [ ] **총 GKE 비용**: 평시 $33/월, 피크 $73/월

#### 4.2 고가용성 설정
- [ ] PodDisruptionBudget 설정 (minAvailable: 1)
- [ ] Health Check 구현
  - [ ] livenessProbe: /health
  - [ ] readinessProbe: /ready
- [ ] Graceful Shutdown 구현 (SIGTERM 처리)

#### 4.3 워크로드 마이그레이션
- [ ] ArgoCD 설정 업데이트 (GKE 클러스터 연결)
- [ ] ConfigMap/Secret 복사
- [ ] 카나리 배포 (트래픽 10% → 50% → 100%)
- [ ] 모니터링 및 에러 확인

#### 4.4 비용 검증
- [ ] 실제 비용 모니터링 (일주일)
- [ ] 예산 초과 시 리소스 조정
- [ ] HPA 동작 확인 (평시 vs 피크)

**완료 기준**:
- 워크로드 GKE 클러스터로 완전 이전
- 월 비용 $75 이하 확인
- 구 EKS 클러스터 종료 준비

---

### Phase 5: DNS 전환 및 트래픽 마이그레이션 (5주차)

**목표**: Istio Ingress Gateway로 트래픽 전환 및 AWS 리소스 정리

**참고**: HTTP(S) Load Balancer는 Istio Ingress Gateway를 통해 자동 생성됨

#### 5.1 Istio Ingress Gateway 외부 IP 확보
- [ ] Istio Ingress Gateway Service (LoadBalancer 타입) 생성
- [ ] External IP 확인 및 고정 (Static IP 예약)
- [ ] Cloud Armor Policy 연동
- [ ] SSL Certificate 연결

#### 5.2 DNS 전환
- [ ] Cloud DNS A 레코드 생성 (LB IP)
- [ ] TTL 짧게 설정 (300초)
- [ ] 도메인 레지스트라에서 NS 레코드 변경
- [ ] DNS 전파 확인 (dig, nslookup)

#### 5.3 트래픽 전환
- [ ] DNS 전환 후 모니터링 (에러율, 레이턴시)
- [ ] 24시간 안정화 확인
- [ ] AWS ALB 트래픽 감소 확인
- [ ] Route53 레코드 삭제 준비

**완료 기준**:
- Istio Ingress Gateway로 100% 트래픽 전환
- SSL 인증서 정상 작동
- Cloud Armor WAF 활성화
- 에러율 0%, 레이턴시 정상

---

### Phase 6: CI/CD 자동화 및 최종 정리 (6주차)

**목표**: Terraform 자동화 완료 및 AWS 리소스 정리

**참고**: GitHub Actions GitOps 워크플로우는 Phase 1에서 이미 구현 완료

#### 6.1 GitHub Actions 워크플로우 검증
- [x] Terraform Plan 자동 실행 (PR 생성 시)
- [x] PR 코멘트로 Plan 결과 표시
- [x] main 병합 시 Terraform Apply 자동 실행
- [ ] Slack/Discord 알림 연동 (선택 사항)

#### 6.2 브랜치 보호 규칙 강화
- [x] main 브랜치 직접 푸시 금지
- [ ] terraform-plan 체크 필수 (Branch Protection Rule)
- [x] Squash and Merge 기본값 설정

#### 6.3 롤백 절차 문서화
- [ ] Terraform State 복원 방법
- [ ] Git Revert 절차
- [ ] 긴급 수동 복구 절차

#### 6.4 모니터링 및 알림 설정
- [ ] Cloud Monitoring Dashboard 생성
  - [ ] GKE Pod CPU/메모리
  - [ ] Cloud SQL 성능
  - [ ] Istio Ingress Gateway 트래픽
- [ ] Budget Alert 설정
  - [ ] GKE $75, Cloud SQL $30, 총 $130
  - [ ] 50%, 75%, 90% 도달 시 알림
- [ ] Error Reporting 알림

#### 6.5 AWS 리소스 정리
- [ ] EKS 클러스터 삭제 (백업 후)
- [ ] RDS 인스턴스 삭제 (최종 스냅샷 생성)
- [ ] ALB/Target Group 삭제
- [ ] Route53 Hosted Zone 삭제
- [ ] CloudWatch Logs 보관 정책 확인
- [ ] 최종 AWS 비용 확인 (종료 후)

**완료 기준**:
- CI/CD 파이프라인 정상 작동
- 모니터링 대시보드 완성
- AWS 리소스 완전 종료
- 월 비용 목표치 달성 ($130 이하)

---

## 예산 추적

### 월별 예상 비용 (1인 개발, 프로덕션 단일 환경) - **비용 최적화 적용**

| 항목 | Phase 1 (최적화 전) | Phase 1 (최적화 후) | Phase 2 (DB 이전) | Phase 3~4 (최종) |
|-----|---------------------|---------------------|-------------------|-----------------|
| Default VPC | - | **$0** | **$0** | **$0** |
| GKE Standard (Free) | - | **$0** | **$0** | **$0** |
| e2-medium Spot (1 node) | - | **$7** | **$7** | **$7~21** |
| External Secrets | - | **$4** | **$4** | **$4** |
| Cloud SQL | - | - | $30 | $30 |
| Load Balancer | - | - | - | $18 |
| Cloud DNS | - | - | $0.4 | $0.4 |
| Cloud Storage | $1 | $1 | $1 | $1 |
| Cloud Armor | - | - | - | $5 |
| **GCP 총 비용** | **$1** | **$12** | **$42** | **$65~79** |
| **AWS 비용 (병렬)** | **$100** | **$100** | **$70** | **$0** |
| **합계** | **$101** | **$112** | **$112** | **$65~79** |

**목표**: Phase 4 완료 후 **월 $80 이하 달성** (평시 $65, 피크 $79)
**비용 절감**: 기존 계획 대비 **$48~$62/월 절감** (약 50% 절감)

### 비용 최적화 포인트 (1인 개발 환경 특화) - **Phase 1 완료**

- [x] **Default VPC 사용**: Custom VPC 대신 Default VPC 사용 (절감: $56/월)
- [x] **GKE Standard + Spot Instance**: Autopilot 대신 Spot 활용 (절감: $33~40/월)
- [x] **Single Zone 배포**: Free Tier GKE 관리 비용 무료 (절감: $73/월)
- [x] **Node Auto-scaling**: 리소스 기반 자동 확장 (1-3 nodes)
- [ ] Cloud SQL: db-g1-small 유지, HA 비활성화 (단일 환경으로 충분)
- [ ] Load Balancer: 단일 LB로 모든 서비스 라우팅 (경로 기반)
- [ ] Cloud Storage: 로그 30일 이후 Nearline 이동
- [x] 개발 환경 없음: 프로덕션 단일 환경으로 50% 비용 절감
- [x] 향후 서비스 추가 시: 동일 GKE 클러스터 내 Pod 추가만으로 확장

**Phase 1 비용 최적화 성과**:
- Custom VPC → Default VPC: **-$56/월**
- GKE Autopilot → Standard + Spot: **-$33/월**
- Multi-zone → Single Zone (Free Tier): **-$73/월**
- **총 절감**: **약 $162/월** (기존 계획 대비)

---

## 리스크 관리

### 리스크 식별 및 대응

| 리스크 | 가능성 | 영향도 | 대응 방안 |
|--------|--------|--------|----------|
| 데이터 마이그레이션 중 손실 | 중간 | 🔴 Critical | 백업 3중화, 롤백 계획 수립 |
| DNS 전환 중 다운타임 | 낮음 | 🟡 High | TTL 300초, 병렬 운영 24시간 |
| GKE 비용 초과 | 중간 | 🟡 High | Budget Alert, 일일 모니터링 |
| Terraform State 손상 | 낮음 | 🔴 Critical | State 버전 관리, 백업 자동화 |
| 1인 운영 중 장애 발생 | 중간 | 🟡 High | 자동화 최대화, 알림 설정 |

### 롤백 계획 (1인 운영 대응)

**Phase별 롤백 시나리오**:

1. **Phase 2 (DB) 롤백**:
   - Cloud SQL → K8s VM으로 복원
   - 백업 데이터 pg_restore
   - 예상 시간: 2시간 (1인 작업)

2. **Phase 3 (GKE) 롤백**:
   - GKE → EKS로 워크로드 복원
   - ArgoCD 설정 되돌리기
   - 예상 시간: 1시간 (단일 환경으로 간단)

3. **Phase 3 (LB/DNS) 롤백**:
   - DNS NS 레코드 Route53으로 복원
   - 예상 시간: 15분 (DNS 전파 대기)

**1인 운영 특화 롤백 전략**:
- 각 Phase 완료 후 24시간 AWS 병렬 운영
- 문제 발생 시 즉시 DNS 전환으로 롤백
- 백업 자동화로 수동 작업 최소화

---

## 성공 기준

### 기술적 성공 지표

- [ ] 다운타임 0분 (DNS 전환 제외)
- [ ] 데이터 손실 0건
- [ ] Terraform으로 100% 인프라 관리
- [ ] CI/CD 자동화 완료 (PR → Plan → Apply)
- [ ] 월 비용 $130 이하 달성

### 운영 성공 지표 (1인 개발 환경)

- [ ] 브루트 포스 공격 차단율 100%
- [ ] 애플리케이션 에러율 0.1% 이하
- [ ] P95 레이턴시 500ms 이하 유지
- [ ] 자동화로 수동 운영 시간 주 2시간 이하

### 비즈니스 성공 지표

- [ ] 월 인프라 비용 30%+ 절감 (AWS $150 → GCP $87~127)
- [ ] 보안 사고 0건
- [ ] CI/CD 자동화로 배포 시간 80% 단축
- [ ] 향후 서비스 추가 시 추가 인프라 비용 최소화 (Pod만 추가)

---

## 다음 단계

### 즉시 착수 가능한 작업

1. **Phase 1 시작**: GCP 프로젝트 생성 및 IAM 설정
2. **Terraform 폴더 구조 생성**: `gcp/terraform/` 초기화
3. **GitHub Actions 기본 워크플로우 작성**: plan.yml 템플릿

### 컨펌 필요 사항

- [ ] Phase별 일정 승인 (4~5주 일정)
- [ ] 예산 최종 확정 (GKE $75, Cloud SQL $30, 총 $130)
- [ ] 데이터베이스 마이그레이션 다운타임 허용 시간
- [ ] DNS 전환 희망 시간대 (주말 vs 평일 야간)
- [ ] 앱 서비스 2개 외 추가 예정 서비스 일정

### 주간 체크포인트 (1인 운영)

**매주 일정**:
- [ ] 완료된 작업 확인
- [ ] 다음 주 작업 계획
- [ ] 리스크 리뷰
- [ ] 예산 사용 현황 점검
- [ ] AWS 리소스 병렬 운영 상태 확인

### 향후 서비스 확장 계획

**새 서비스 추가 시 절차** (기존 인프라 활용):
1. 새 Deployment YAML 작성
2. ArgoCD에 Application 추가
3. Ingress 라우팅 규칙 추가 (기존 LB 활용)
4. HPA 설정으로 비용 최적화
5. **추가 인프라 비용**: Pod 리소스 비용만 ($5~20/서비스)

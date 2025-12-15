# GCP Terraform 리소스 현황

**최종 업데이트**: 2025-12-15 (Service Networking API 활성화 완료)
**프로젝트**: infra-480802
**리전**: asia-northeast3 (서울)

---

## 📊 현재 배포된 리소스 (Phase 1)

### ✅ 네트워킹 (5개 리소스)

| 리소스 유형 | 이름 | 상태 | 설명 |
|------------|------|------|------|
| VPC Network | `woohalabs-prod-vpc` | 🟢 Active | 메인 VPC 네트워크 |
| Subnet | `woohalabs-prod-private-subnet` | 🟢 Active | Private 서브넷 (10.0.0.0/24) |
| Cloud Router | `woohalabs-prod-router` | 🟢 Active | NAT용 라우터 |
| Cloud NAT | `woohalabs-prod-nat` | 🟢 Active | 외부 통신용 NAT 게이트웨이 |
| Firewall Rule | `woohalabs-prod-allow-internal` | 🟢 Active | 내부 통신 허용 규칙 |

**네트워크 CIDR 구성**:
- Primary Subnet: `10.0.0.0/24` (256 IPs)
- Pods Range: `10.1.0.0/16` (65,536 IPs)
- Services Range: `10.2.0.0/16` (65,536 IPs)

### ✅ 컴퓨팅 (1개 리소스)

| 리소스 유형 | 이름 | 상태 | 설명 |
|------------|------|------|------|
| GKE Autopilot | `woohalabs-prod-gke-cluster` | 🟢 Active | Kubernetes 클러스터 (Autopilot) |

**GKE 클러스터 상세**:
- 모드: Autopilot (완전 관리형)
- 리전: asia-northeast3 (Multi-AZ)
- Release Channel: REGULAR
- Maintenance Window: 03:00 UTC (12:00 KST)
- Network: woohalabs-prod-vpc
- Subnet: woohalabs-prod-private-subnet

---

## 🔄 Phase 2 예정 리소스 (미배포)

### ⏸️ 데이터베이스

| 리소스 유형 | 예정 이름 | 상태 | 우선순위 |
|------------|----------|------|---------|
| Cloud SQL | `woohalabs-prod-cloudsql` | ⏸️ Pending | High |

### ⏸️ 네트워킹 & 보안

| 리소스 유형 | 예정 이름 | 상태 | 우선순위 |
|------------|----------|------|---------|
| Load Balancer | `woohalabs-prod-lb` | ⏸️ Pending | High |
| Cloud DNS | `woohalabs-prod-dns` | ⏸️ Pending | Medium |
| SSL Certificate | `woohalabs-prod-ssl` | ⏸️ Pending | High |
| Cloud Armor | `woohalabs-prod-armor` | ⏸️ Pending | Medium |

### ⏸️ 기타

| 리소스 유형 | 예정 이름 | 상태 | 우선순위 |
|------------|----------|------|---------|
| External Secrets | `woohalabs-prod-secrets` | ⏸️ Pending | Low |
| IAM Roles | `woohalabs-prod-iam-*` | ⏸️ Pending | Medium |

---

## 📈 리소스 히스토리

### 2025-12-15: ArgoCD-Istio Ingress Gateway 통합 완료

**배포된 변경사항**: ArgoCD Service 타입 변경 및 Istio 통합
**예상 소요 시간**: 약 3-5분

**변경 내역**:
- ArgoCD Service 타입: LoadBalancer → ClusterIP
- ArgoCD 도메인 설정: argocd.ggorockee.com
- OAuth redirectURI 업데이트: argocd.ggorockee.com/api/dex/callback
- Istio VirtualService 활성화 (이미 설정되어 있음)
- 외부 접근 경로: Istio Ingress Gateway (34.50.12.202) → main-gateway → argocd-vs → argocd-server

**통합 효과**:
- 중복 LoadBalancer 제거 (월 비용 절감: $15-20 예상)
- 통합 Gateway를 통한 일관된 보안 정책 적용
- TLS 인증서 자동 갱신 (cert-manager)
- 트래픽 관리 중앙화 (main-gateway)

**트래픽 흐름**:
```
Internet → argocd.ggorockee.com (HTTPS)
       ↓
34.50.12.202 (Istio Ingress Gateway)
       ↓
main-gateway (istio-system namespace)
       ↓
argocd-vs VirtualService (argocd namespace)
       ↓
argocd-server Service (ClusterIP)
       ↓
argocd-server Pod
```

### 2025-12-14: Phase 1 배포 완료

**배포된 리소스**: 6개
**소요 시간**: 약 9분 23초

**변경 내역**:
- VPC 네트워크 생성: woohalabs-prod-vpc
- Private 서브넷 생성: woohalabs-prod-private-subnet
- Cloud Router 생성: woohalabs-prod-router
- Cloud NAT 생성: woohalabs-prod-nat
- 방화벽 규칙 생성: woohalabs-prod-allow-internal
- GKE Autopilot 클러스터 생성: woohalabs-prod-gke-cluster

**Terraform 출력**:
```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:
gke_cluster_endpoint = <sensitive>
gke_cluster_name = "woohalabs-prod-gke-cluster"
network_name = "woohalabs-prod-vpc"
```

---

## 💰 예상 월별 비용

| 리소스 카테고리 | 월 예상 비용 (USD) | 비율 |
|----------------|------------------|------|
| GKE Autopilot | $50-70 | 38-54% |
| Cloud NAT | $35-40 | 27-31% |
| Cloud Storage | $5-10 | 4-8% |
| 네트워킹 (VPC, Subnet) | $0-5 | 0-4% |
| **총합** | **$90-125** | **100%** |

**예산 대비**: $130/월 예산 → 약 69-96% 사용 예정

---

## 🔧 Terraform 모듈 구조

### 활성화된 모듈 (Phase 1)

**environments/prod/main.tf**:
```
✅ module.networking
   - VPC, Subnet, Router, NAT, Firewall

✅ module.gke
   - GKE Autopilot Cluster
```

### 비활성화된 모듈 (Phase 2)

```
⏸️ module.cloud_sql (주석 처리)
⏸️ module.dns (주석 처리)
⏸️ module.cloud_armor (주석 처리)
⏸️ module.ssl_certificate (주석 처리)
⏸️ module.load_balancer (주석 처리)
⏸️ module.external_secrets (주석 처리)
⏸️ module.iam (주석 처리)
```

---

## 📝 문서 업데이트 규칙

**⚠️ 중요**: Terraform 리소스가 변경될 때마다 이 문서를 **반드시** 업데이트해야 합니다.

### 업데이트 트리거

다음 작업 시 이 문서를 함께 업데이트:

1. **리소스 추가/삭제**
   - `terraform apply`로 리소스 생성/삭제 시
   - 모듈 활성화/비활성화 시

2. **리소스 이름 변경**
   - 네이밍 컨벤션 변경 시
   - 환경(prod/dev/staging) 변경 시

3. **Phase 진행**
   - Phase 2, 3 등으로 진행 시
   - 우선순위 변경 시

4. **비용 변동**
   - 리소스 추가로 인한 비용 증가 시
   - 월별 실제 비용 확인 후

### 업데이트 체크리스트

Terraform 변경 시 다음을 확인:

- [ ] 현재 배포된 리소스 테이블 업데이트
- [ ] Phase 2 예정 리소스 상태 변경
- [ ] 리소스 히스토리에 변경 내역 추가
- [ ] 예상 월별 비용 재계산
- [ ] Terraform 모듈 구조 상태 업데이트
- [ ] 최종 업데이트 날짜 수정

### 커밋 메시지 규칙

```bash
# Terraform 리소스 변경 시
git commit -m "feat: Cloud SQL 모듈 추가

- Cloud SQL PostgreSQL 인스턴스 생성
- TERRAFORM_RESOURCES.md 업데이트
- Phase 2 진행률: 1/7 완료"
```

---

## 🔗 관련 문서

- [GCP Terraform Architecture](../../docs/gcp-terraform-architecture.md)
- [GKE Autopilot Strategy](../../docs/gcp-gke-autopilot-strategy.md)
- [GCP Migration Master Plan](../../docs/workload/gcp-migration-master-plan.md)
- [GitHub Actions Workflows](../../.github/workflows/README.md)

---

## 📞 문의 및 지원

Terraform 관련 문제 발생 시:
1. GitHub Actions 워크플로우 로그 확인
2. GCP Console에서 리소스 상태 확인
3. `terraform state list` 명령으로 State 확인
4. Issue 생성: `infra/issues`

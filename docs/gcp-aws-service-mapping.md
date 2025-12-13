# GCP ↔ AWS 서비스 매핑 및 마이그레이션 전략

## AWS 워크로드의 GCP 전환

현재 AWS 구성: Route53 + WAF + ALB + ACM + Wildcard 인증서

### 서비스 매핑

| AWS 서비스 | GCP 서비스 | 역할 |
|-----------|-----------|------|
| Route 53 | Cloud DNS | DNS 관리 및 도메인 라우팅 |
| WAF (Web Application Firewall) | Cloud Armor | DDoS 방어 및 웹 애플리케이션 방화벽 |
| ALB (Application Load Balancer) | Cloud Load Balancing (HTTP(S)) | 레이어 7 로드 밸런싱 |
| ACM (Certificate Manager) | Google-managed SSL Certificates | SSL/TLS 인증서 자동 관리 |
| Wildcard 인증서 | Wildcard SSL Certificate | `*.domain.com` 패턴 지원 |

## GCP 아키텍처 구성

### 1. Cloud DNS 설정

**목적**: 도메인 관리 및 DNS 레코드 설정

**Terraform 모듈**: `modules/dns/`

**주요 설정**:
- Managed Zone 생성
- A/AAAA 레코드: Load Balancer IP 연결
- CNAME 레코드: 서브도메인 설정

### 2. Cloud Armor (WAF)

**목적**: 웹 애플리케이션 보안 및 DDoS 방어

**Terraform 모듈**: `modules/cloud-armor/`

**주요 기능**:
- IP 화이트리스트/블랙리스트
- Rate limiting (요청 속도 제한)
- Geo-blocking (특정 국가 차단)
- OWASP Top 10 방어 규칙

**AWS WAF 대비 장점**:
- Google Cloud Armor는 기본적으로 DDoS 방어 포함
- 더 간단한 규칙 설정

### 3. HTTP(S) Load Balancer

**목적**: 글로벌 로드 밸런싱 및 SSL 종료

**Terraform 모듈**: `modules/load-balancer/`

**구성 요소**:
- Frontend (IP 주소, SSL 인증서)
- URL Map (라우팅 규칙)
- Backend Service (타겟 서비스)
- Health Check (헬스 체크 설정)

### 4. Managed SSL Certificate (Wildcard)

**목적**: 자동 갱신 SSL 인증서

**Terraform 모듈**: `modules/ssl-certificate/`

**설정 예시**:
- 도메인: `*.woohalabs.com`
- 자동 갱신: Google이 자동으로 90일마다 갱신
- Let's Encrypt 스타일 (무료)

## AWS ALB 최소화 전략의 GCP 적용

### AWS 전략: 단일 ALB + 다중 타겟그룹

**현재 AWS 구성 (추정)**:
- 1개의 ALB
- 여러 타겟그룹 (서비스별)
- 리스너 규칙으로 호스트/패스 기반 라우팅

### GCP 전환: 단일 Load Balancer + URL Map

**GCP 구성**:
- 1개의 HTTP(S) Load Balancer
- 1개의 URL Map (라우팅 규칙)
- 여러 Backend Service (서비스별)

**URL Map 라우팅 예시**:

| 호스트/패스 | Backend Service | 설명 |
|-----------|----------------|------|
| `api.woohalabs.com/*` | gke-api-backend | API 서버 |
| `admin.woohalabs.com/*` | gke-admin-backend | 어드민 서버 |
| `*.woohalabs.com/*` | gke-default-backend | 기본 서비스 |

**비용 절감 효과**:
- AWS: ALB당 시간당 $0.0225 (월 $16)
- GCP: Load Balancer 기본 요금 없음, 트래픽 기반 과금
- GCP가 소규모 트래픽에서 더 유리

### URL Map 기반 라우팅 전략

**Path Matcher 설정**:
- Host 기반: `api.domain.com` → API backend
- Path 기반: `/admin/*` → Admin backend
- Default: 기본 backend

**Health Check 설정**:
- 각 Backend Service별 독립적인 헬스 체크
- Kubernetes의 readiness probe와 연동

## Terraform 구현 예시 (개념)

**URL Map 리소스 구조**:
- `google_compute_url_map`: 라우팅 규칙 정의
- `google_compute_backend_service`: 각 서비스별 백엔드
- `google_compute_health_check`: 헬스 체크 설정

**Backend Service 연결**:
- GKE: Network Endpoint Group (NEG) 사용
- Instance Group 또는 NEG를 Backend로 설정

## 마이그레이션 체크리스트

- [ ] Cloud DNS Managed Zone 생성
- [ ] Cloud Armor 보안 정책 설정
- [ ] Wildcard SSL 인증서 프로비저닝 (도메인 소유권 검증 필요)
- [ ] HTTP(S) Load Balancer 생성
- [ ] URL Map 라우팅 규칙 설정
- [ ] Backend Service를 GKE NEG에 연결
- [ ] Health Check 설정 및 테스트
- [ ] DNS A 레코드를 Load Balancer IP로 변경
- [ ] TTL 고려한 단계적 마이그레이션

## 비교 요약

| 측면 | AWS | GCP | 비고 |
|-----|-----|-----|------|
| 로드 밸런서 | ALB | HTTP(S) LB | GCP가 글로벌 기본 제공 |
| 비용 | 시간당 고정 요금 | 트래픽 기반 | 소규모는 GCP 유리 |
| SSL 인증서 | ACM (무료) | Google-managed (무료) | 둘 다 자동 갱신 |
| WAF | AWS WAF (유료) | Cloud Armor (유료) | GCP가 DDoS 포함 |
| DNS | Route 53 | Cloud DNS | 기능 유사 |
| 설정 복잡도 | 중간 | 낮음 | GCP가 더 간단 |

## 권장 사항

1. **단일 Load Balancer 전략 유지**: GCP에서도 1개의 HTTP(S) LB + URL Map으로 구성
2. **Cloud Armor 적용**: 기본 DDoS 방어 + 커스텀 규칙 설정
3. **Wildcard 인증서 사용**: `*.woohalabs.com`으로 모든 서브도메인 커버
4. **단계적 마이그레이션**: DNS TTL을 줄이고 단계적으로 트래픽 전환

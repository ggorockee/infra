# Istio Gateway Config Helm Chart

Istio Gateway, VirtualService, Rate Limiting (비용 최소화), Authorization Policy를 통합 관리하는 Helm 차트입니다.

## 개요

이 Helm 차트는 다음을 제공합니다:

- **Istio Gateway**: HTTP/HTTPS 트래픽 라우팅
- **VirtualService**: 경로 기반 라우팅
- **Rate Limiting**: Istio EnvoyFilter를 사용한 로컬 Rate Limiting (비용 $0)
- **Authorization Policy**: IP 화이트리스트, User-Agent 차단, 국가 차단

## 비용 최적화 전략

**Cloud Armor 대신 Istio 자체 보안 기능 사용**:
- Cloud Armor 비용: **$5/월** → **$0/월**
- Istio Local Rate Limiting: 추가 비용 없음
- 동일한 브루트 포스 방지 효과

## 주요 기능

### 1. Gateway 설정

| 기능 | 설명 | 비용 |
|-----|------|-----|
| HTTP → HTTPS 리다이렉트 | 자동 HTTPS 전환 | $0 |
| Multi-domain TLS | 여러 도메인 SSL 인증서 지원 | $0 |
| Let's Encrypt | cert-manager 통합 | $0 |

### 2. Rate Limiting (브루트 포스 방지)

| 타입 | 제한 | 용도 |
|-----|------|-----|
| Global | 100 req/min | 전체 트래픽 |
| Login Path | 10 req/min | 로그인 브루트 포스 방지 |
| Admin Path | 30 req/min | 관리자 경로 보호 |

**작동 원리**:
- Token Bucket 알고리즘 사용
- Rate Limit 초과 시 HTTP 429 응답
- 로컬 처리로 비용 및 지연시간 최소화

### 3. Authorization Policy

| 보안 기능 | 기본값 | 설명 |
|----------|--------|------|
| HTTP 메서드 제한 | 활성화 | 허용된 메서드만 통과 |
| User-Agent 차단 | 활성화 | 악성 봇 자동 차단 |
| IP 화이트리스트 | 비활성화 | 필요 시 활성화 |
| 국가 차단 | 비활성화 | 필요 시 활성화 |

## 설정 방법

### values.yaml 주요 설정

#### Rate Limiting 설정

```yaml
security:
  rateLimit:
    enabled: true

    # 전체 트래픽 제한
    global:
      maxTokens: 100
      tokensPerFill: 100
      fillInterval: "60s"

    # 로그인 경로 (브루트 포스 방지)
    loginPath:
      enabled: true
      maxTokens: 10
      fillInterval: "60s"
      paths:
        - "/api/auth/login"
        - "/login"
```

#### Authorization Policy 설정

```yaml
security:
  authorization:
    enabled: true

    # 악성 봇 차단
    userAgentBlacklist:
      enabled: true
      patterns:
        - "*sqlmap*"
        - "*nikto*"

    # IP 화이트리스트 (선택)
    ipWhitelist:
      enabled: false
      allowedIPs:
        - "YOUR_OFFICE_IP/32"
```

### Gateway 설정

```yaml
gateway:
  enabled: true
  name: main-gateway
  namespace: istio-system

  # HTTPS TLS 설정
  https:
    enabled: true
    port: 443
    tls:
      - name: example-com
        hosts:
          - "*.example.com"
          - "example.com"
        credentialName: example-com-wildcard-tls
```

### VirtualService 설정

```yaml
virtualServices:
  - name: my-app-vs
    namespace: my-app
    enabled: true
    hosts:
      - "app.example.com"
    http:
      - route:
          - destination:
              host: my-app-service
              port: 80
```

## 배포 방법

### ArgoCD를 통한 자동 배포

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-gateway-config
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/infra
    targetRevision: main
    path: charts/helm/prod/istio-gateway-config
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Helm CLI를 통한 수동 배포

- Helm 설치
- values.yaml 수정
- 배포 실행
- 상태 확인

## Rate Limiting 테스트

### Global Rate Limiting 테스트

초당 100회 요청 시도 시 HTTP 429 응답 확인

### Login Path Rate Limiting 테스트

로그인 경로로 분당 10회 이상 요청 시 차단 확인

### 헤더 확인

Rate Limit 초과 시 다음 헤더 반환:
- `x-local-rate-limit: true`
- `x-rate-limit-reason: global-limit-exceeded`

## 보안 검증

### User-Agent 차단 테스트

악성 봇 User-Agent로 요청 시 차단 확인

### Authorization Policy 확인

허용되지 않은 HTTP 메서드 요청 시 차단 확인

## 모니터링

### Istio 메트릭 확인

Rate Limiting 통계 확인

### 로그 확인

차단된 요청 로그 확인

## 문제 해결

### Rate Limiting이 작동하지 않는 경우

1. EnvoyFilter 상태 확인
2. Istio Ingress Gateway Pod 재시작
3. Rate Limit 설정 검증

### Authorization Policy 오작동

1. Policy 상태 확인
2. 허용된 메서드 및 IP 확인
3. User-Agent 패턴 검증

## 비용 비교

| 항목 | Cloud Armor | Istio Rate Limiting |
|-----|-------------|---------------------|
| 월 비용 | $5 + 트래픽 비용 | $0 |
| 브루트 포스 방지 | O | O |
| Rate Limiting | O | O |
| IP 차단 | O | O |
| 국가 차단 | O | △ (제한적) |
| DDoS 방어 | O | X |

**결론**: 1인 개발 환경에서는 Istio Rate Limiting으로 충분하며, 비용을 $5/월 절감할 수 있습니다.

## 향후 확장

### Cloud Armor 추가 (필요 시)

DDoS 방어가 필요한 경우에만 Cloud Armor 활성화:
- BackendConfig 리소스 생성
- Istio Service에 annotation 추가
- Security Policy 연결

### 추가 보안 기능

- mTLS (Mutual TLS) 활성화
- JWT 인증 추가
- RBAC 정책 강화

## 참고 자료

- Istio Rate Limiting: https://istio.io/latest/docs/tasks/policy-enforcement/rate-limit/
- Istio Authorization Policy: https://istio.io/latest/docs/reference/config/security/authorization-policy/
- Envoy Local Rate Limiting: https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/local_rate_limit_filter

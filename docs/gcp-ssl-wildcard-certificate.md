# GCP Wildcard SSL 인증서 설정 가이드

## 개요

Let's Encrypt를 사용하여 `*.woohalabs.com` Wildcard SSL 인증서를 자동으로 발급하고, Istio Gateway에 적용합니다.

**핵심 기술**:
- **cert-manager**: Kubernetes용 인증서 관리 도구
- **Let's Encrypt**: 무료 SSL 인증서 발급 기관
- **DNS-01 Challenge**: Wildcard 인증서 발급을 위한 검증 방식
- **Cloud DNS**: GCP 관리형 DNS 서비스

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                     Let's Encrypt                           │
│                 (ACME Server)                               │
└──────────────────┬──────────────────────────────────────────┘
                   │ ACME Protocol
                   │ DNS-01 Challenge
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                   cert-manager                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ ClusterIssuer (letsencrypt-prod)                     │   │
│  │ ├─ ACME Server: Let's Encrypt Production            │   │
│  │ ├─ Email: woohaen88@gmail.com                        │   │
│  │ └─ Solver: DNS-01 (Cloud DNS)                        │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Certificate (woohalabs-wildcard-cert)                │   │
│  │ ├─ DNSNames: woohalabs.com, *.woohalabs.com         │   │
│  │ └─ SecretName: woohalabs-wildcard-tls                │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────┬───────────────────────────────────────────────┘
               │ Creates Secret
               ▼
┌─────────────────────────────────────────────────────────────┐
│          Kubernetes Secret                                  │
│  woohalabs-wildcard-tls (namespace: istio-system)          │
│  ├─ tls.crt (Public Certificate)                           │
│  └─ tls.key (Private Key)                                  │
└──────────────┬───────────────────────────────────────────────┘
               │ Referenced by
               ▼
┌─────────────────────────────────────────────────────────────┐
│          Istio Gateway                                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ HTTPS (443)                                          │   │
│  │ ├─ Hosts: *.woohalabs.com, woohalabs.com           │   │
│  │ └─ TLS: credentialName: woohalabs-wildcard-tls      │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│     istio-ingressgateway LoadBalancer                       │
│     External IP: 34.50.12.202                              │
└─────────────────────────────────────────────────────────────┘
```

## 사전 요구사항

### 1. Cloud DNS Zone 생성

**수동 설정 필요**:

1. GCP Console → Cloud DNS → Create Zone
2. Zone 설정:
   - Zone name: `woohalabs-com`
   - DNS name: `woohalabs.com`
   - Zone type: Public

3. 도메인 등록 업체에서 네임서버 변경:
   ```
   ns-cloud-a1.googledomains.com
   ns-cloud-a2.googledomains.com
   ns-cloud-a3.googledomains.com
   ns-cloud-a4.googledomains.com
   ```

### 2. DNS 레코드 설정

Cloud DNS에서 A 레코드 추가:

```
Name: @ (apex)
Type: A
TTL: 300
Data: 34.50.12.202

Name: *
Type: A
TTL: 300
Data: 34.50.12.202
```

## 배포 순서

### Phase 1: Terraform으로 cert-manager 배포

**environments/prod/main.tf에 추가**:

```hcl
# Phase 4: cert-manager deployment
module "cert_manager" {
  source = "../../modules/cert-manager"

  project_id       = var.project_id
  region           = var.region
  environment      = var.environment
  cluster_name     = module.gke.cluster_name
  cluster_location = module.gke.cluster_location

  depends_on = [module.argocd]
}
```

**배포**:

```bash
cd gcp/terraform/environments/prod
terraform plan
terraform apply
```

**생성되는 리소스**:
- ✅ cert-manager namespace
- ✅ cert-manager Helm release
- ✅ GCP Service Account (DNS-01 solver)
- ✅ IAM Binding (dns.admin role)
- ✅ Workload Identity Binding
- ✅ Kubernetes Secret (Cloud DNS credentials)

### Phase 2: ClusterIssuer 생성

```bash
kubectl apply -f k8s-manifests/cert-manager/clusterissuer-letsencrypt.yaml
```

**검증**:

```bash
kubectl get clusterissuer
```

예상 출력:
```
NAME                  READY   AGE
letsencrypt-prod      True    10s
letsencrypt-staging   True    10s
```

### Phase 3: Wildcard Certificate 발급

```bash
kubectl apply -f k8s-manifests/cert-manager/certificate-wildcard.yaml
```

**검증**:

```bash
# Certificate 상태 확인
kubectl get certificate -n istio-system

# Certificate 상세 정보
kubectl describe certificate woohalabs-wildcard-cert -n istio-system

# Secret 생성 확인
kubectl get secret woohalabs-wildcard-tls -n istio-system
```

**발급 과정** (약 2-5분 소요):
1. cert-manager가 Certificate 리소스 감지
2. Let's Encrypt에 인증서 요청
3. DNS-01 Challenge 시작:
   - Cloud DNS에 TXT 레코드 자동 생성 (`_acme-challenge.woohalabs.com`)
   - Let's Encrypt가 DNS 레코드 검증
   - 검증 완료 후 TXT 레코드 자동 삭제
4. 인증서 발급 및 Secret 생성

**문제 해결**:

```bash
# cert-manager 로그 확인
kubectl logs -n cert-manager -l app=cert-manager -f

# Certificate 이벤트 확인
kubectl describe certificate woohalabs-wildcard-cert -n istio-system

# CertificateRequest 확인
kubectl get certificaterequest -n istio-system
kubectl describe certificaterequest <request-name> -n istio-system
```

### Phase 4: Istio Gateway HTTPS 설정

```bash
kubectl apply -f k8s-manifests/istio/gateway-https.yaml
```

**Gateway 구성**:
- **HTTP (80)**: HTTPS로 자동 리다이렉트
- **HTTPS (443)**: Wildcard 인증서 사용

**VirtualService 예제**:
- `argocd.woohalabs.com` → ArgoCD
- `ojeomneo.woohalabs.com` → Ojeomneo Admin
- `api.ojeomneo.woohalabs.com` → Ojeomneo API

## 인증서 자동 갱신

**cert-manager가 자동으로 처리**:
- 만료 30일 전 자동 갱신 시작
- 갱신 프로세스:
  1. 새 Certificate 요청
  2. DNS-01 Challenge 재수행
  3. 새 인증서로 Secret 업데이트
  4. Istio Gateway 자동 reload

**갱신 상태 모니터링**:

```bash
# Certificate 갱신 일정 확인
kubectl get certificate -n istio-system -o wide

# cert-manager 로그 모니터링
kubectl logs -n cert-manager -l app=cert-manager --tail=100 -f
```

## 테스트

### 1. HTTPS 접속 테스트

```bash
# ArgoCD
curl -I https://argocd.woohalabs.com

# 인증서 정보 확인
openssl s_client -connect argocd.woohalabs.com:443 -servername argocd.woohalabs.com < /dev/null
```

### 2. HTTP → HTTPS 리다이렉트 테스트

```bash
curl -I http://argocd.woohalabs.com
# Expected: 301 Moved Permanently
# Location: https://argocd.woohalabs.com
```

### 3. Wildcard 서브도메인 테스트

```bash
curl -I https://api.woohalabs.com
curl -I https://app.woohalabs.com
# 모든 서브도메인이 동일한 인증서 사용
```

## 비용

**무료**:
- ✅ cert-manager: 오픈소스
- ✅ Let's Encrypt: 무료
- ✅ Cloud DNS: $0.20/zone/month + $0.40/million queries

**예상 Cloud DNS 비용**: **~$1/month**

## 보안 고려사항

### 1. Rate Limit (Let's Encrypt)

**Production 환경**:
- 인증서 발급: 50개/week/도메인
- 중복 인증서: 5개/week

**권장사항**:
- 테스트는 `letsencrypt-staging` 사용
- Production 배포 전 충분한 테스트

### 2. Secret 보안

```bash
# RBAC으로 Secret 접근 제한
kubectl create role secret-reader \
  --verb=get,list \
  --resource=secrets \
  --namespace=istio-system

# Service Account에만 권한 부여
kubectl create rolebinding istio-secret-reader \
  --role=secret-reader \
  --serviceaccount=istio-system:istio-ingressgateway-service-account \
  --namespace=istio-system
```

### 3. Private Key 보호

- ✅ Secret은 etcd에 암호화 저장 (GKE 기본값)
- ✅ RBAC으로 접근 제어
- ✅ cert-manager만 Secret 수정 가능

## 참고 문서

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt DNS-01 Challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)
- [Istio Gateway TLS Configuration](https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/)
- [Cloud DNS Documentation](https://cloud.google.com/dns/docs)

## 트러블슈팅

### Issue 1: Certificate가 Ready 상태가 안됨

**증상**:
```
kubectl get certificate -n istio-system
NAME                      READY   SECRET                    AGE
woohalabs-wildcard-cert   False   woohalabs-wildcard-tls    5m
```

**해결**:

```bash
# Certificate 상세 확인
kubectl describe certificate woohalabs-wildcard-cert -n istio-system

# cert-manager 로그 확인
kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Cloud DNS 권한 확인
kubectl get secret clouddns-dns01-solver-sa -n cert-manager -o yaml
```

**일반적인 원인**:
1. Cloud DNS Zone이 없음
2. Service Account 권한 부족 (`roles/dns.admin` 필요)
3. DNS 전파 대기 시간 (최대 5분)

### Issue 2: DNS-01 Challenge 실패

**로그 예시**:
```
Waiting for DNS-01 challenge propagation: DNS record not yet propagated
```

**해결**:
1. Cloud DNS Zone 확인:
   ```bash
   gcloud dns managed-zones list
   ```

2. DNS 레코드 전파 확인:
   ```bash
   dig _acme-challenge.woohalabs.com TXT
   ```

3. 시간 대기 (최대 10분)

### Issue 3: Istio Gateway에서 인증서 인식 안됨

**증상**: HTTPS 접속 시 인증서 오류

**해결**:

```bash
# Secret이 올바른 namespace에 있는지 확인
kubectl get secret woohalabs-wildcard-tls -n istio-system

# Secret 내용 확인
kubectl get secret woohalabs-wildcard-tls -n istio-system -o yaml

# Istio Gateway Pod 재시작
kubectl rollout restart deployment istio-ingressgateway -n istio-system
```

## 다음 단계

1. **Monitoring 설정**:
   - cert-manager metrics를 Prometheus로 수집
   - 인증서 만료 알림 설정

2. **추가 도메인**:
   - 다른 도메인에 대한 Certificate 추가
   - Multi-domain 인증서 설정

3. **성능 최적화**:
   - TLS 1.3 사용
   - OCSP Stapling 활성화

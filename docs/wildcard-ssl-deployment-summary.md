# Wildcard SSL 인증서 배포 요약

## 📋 개요

**3개 도메인**에 대한 **Wildcard SSL 인증서** 자동 발급 및 Istio Gateway 연동

**도메인**:
- `*.ggorockee.com` + `ggorockee.com`
- `*.ggorockee.org` + `ggorockee.org`
- `*.woohalabs.com` + `woohalabs.com`

**발급 기관**: Let's Encrypt (무료)
**검증 방식**: DNS-01 Challenge
**자동 갱신**: cert-manager (30일 전 자동)

## 🎯 생성된 리소스

### Terraform 모듈
```
gcp/terraform/modules/cert-manager/
├── main.tf       # cert-manager 배포 + Cloud DNS IAM
├── variables.tf
└── outputs.tf
```

### Helm Charts (cert-manager)
```
charts/helm/prod/cert-manager/cert-manager/
├── Chart.yaml                      # jetstack/cert-manager v1.19.2
├── values.yaml                     # cert-manager 설정 + SSL 구성
└── templates/
    ├── clusterissuer.yaml          # Let's Encrypt Production + Staging Issuer
    └── certificates.yaml           # 3개 도메인 Wildcard 인증서
```

### Kubernetes Manifests (Istio)
```
k8s-manifests/istio/
└── gateway-https.yaml              # HTTPS Gateway + VirtualService
```

## 📦 생성될 인증서 및 Secret

| 도메인 | Certificate 이름 | Secret 이름 | 네임스페이스 |
|--------|------------------|-------------|--------------|
| ggorockee.com | ggorockee-com-wildcard-cert | ggorockee-com-wildcard-tls | istio-system |
| ggorockee.org | ggorockee-org-wildcard-cert | ggorockee-org-wildcard-tls | istio-system |
| woohalabs.com | woohalabs-com-wildcard-cert | woohalabs-com-wildcard-tls | istio-system |

## 🚀 배포 순서

### 1. Cloud DNS Zone 생성 (수동 - GCP Console)

**각 도메인마다 Zone 생성 필요**:

| 도메인 | Zone Name | DNS Name |
|--------|-----------|----------|
| ggorockee.com | ggorockee-com | ggorockee.com |
| ggorockee.org | ggorockee-org | ggorockee.org |
| woohalabs.com | woohalabs-com | woohalabs.com |

**생성 방법**:
1. GCP Console → Cloud DNS → Create Zone
2. Zone type: Public
3. DNSSEC: Off (또는 On)

**네임서버 설정** (도메인 등록 업체):
```
ns-cloud-a1.googledomains.com
ns-cloud-a2.googledomains.com
ns-cloud-a3.googledomains.com
ns-cloud-a4.googledomains.com
```

### 2. DNS A 레코드 추가

**각 Zone에 추가**:
```
Name: @
Type: A
TTL: 300
Data: 34.50.12.202  (Istio Ingress Gateway IP)

Name: *
Type: A
TTL: 300
Data: 34.50.12.202
```

### 3. Terraform 배포

**environments/prod/main.tf에 추가**:
```hcl
# Phase 5: cert-manager deployment
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

**실행**:
```bash
cd gcp/terraform/environments/prod
terraform init
terraform plan
terraform apply
```

**생성되는 리소스**:
- ✅ cert-manager namespace
- ✅ cert-manager Helm release
- ✅ GCP Service Account (cert-manager-dns01-prod)
- ✅ IAM Binding (roles/dns.admin)
- ✅ Workload Identity Binding
- ✅ Kubernetes Secret (clouddns-dns01-solver-sa)

### 4. cert-manager Helm Chart 업그레이드

**ClusterIssuer 및 Certificate가 자동 생성됨**:

ArgoCD가 자동으로 Helm 차트를 동기화하거나, 수동으로 업그레이드:

- ArgoCD에서 cert-manager Application Sync
- 또는 수동 Helm 업그레이드 (필요 시):
  `helm upgrade cert-manager ./charts/helm/prod/cert-manager/cert-manager -n cert-manager`

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

### 5. Certificate 발급 확인 (3개 도메인)

**Helm 차트 배포 시 자동 생성됨**

**검증**:
```bash
kubectl get certificate -n istio-system
```

예상 출력:
```
NAME                          READY   SECRET                        AGE
ggorockee-com-wildcard-cert   True    ggorockee-com-wildcard-tls    2m
ggorockee-org-wildcard-cert   True    ggorockee-org-wildcard-tls    2m
woohalabs-com-wildcard-cert   True    woohalabs-com-wildcard-tls    2m
```

**발급 과정** (도메인당 2-5분):
1. cert-manager가 Certificate 리소스 감지
2. Let's Encrypt에 인증서 요청
3. DNS-01 Challenge:
   - Cloud DNS에 TXT 레코드 생성
   - Let's Encrypt가 DNS 검증
   - TXT 레코드 자동 삭제
4. 인증서 발급 및 Secret 생성

### 6. Istio Gateway HTTPS 설정

```bash
kubectl apply -f k8s-manifests/istio/gateway-https.yaml
```

**검증**:
```bash
kubectl get gateway -n istio-system
kubectl get virtualservice -A
```

## 🧪 테스트

### 1. HTTPS 접속 테스트

```bash
# ggorockee.com
curl -I https://ojeomneo.ggorockee.com
curl -I https://api.ojeomneo.ggorockee.com

# ggorockee.org
curl -I https://reviewmaps.ggorockee.org

# woohalabs.com
curl -I https://argocd.woohalabs.com
```

### 2. HTTP → HTTPS 리다이렉트 테스트

```bash
curl -I http://ojeomneo.ggorockee.com
# Expected: 301 Moved Permanently → https://
```

### 3. 인증서 정보 확인

```bash
# ggorockee.com 인증서 확인
echo | openssl s_client -connect ojeomneo.ggorockee.com:443 -servername ojeomneo.ggorockee.com 2>/dev/null | openssl x509 -noout -text

# Wildcard 확인
echo | openssl s_client -connect ojeomneo.ggorockee.com:443 2>/dev/null | openssl x509 -noout -text | grep "DNS:"
# Expected: DNS:*.ggorockee.com, DNS:ggorockee.com
```

## 🔄 자동 갱신

**cert-manager가 자동 처리**:
- 만료 30일 전 갱신 시작
- DNS-01 Challenge 재수행
- 새 인증서로 Secret 업데이트
- Istio Gateway 자동 reload

**모니터링**:
```bash
# Certificate 상태 확인
kubectl get certificate -n istio-system -o wide

# cert-manager 로그
kubectl logs -n cert-manager -l app=cert-manager -f
```

## 📍 도메인별 애플리케이션 매핑

| 도메인 | 애플리케이션 | 서비스 | 네임스페이스 |
|--------|-------------|--------|--------------|
| **ggorockee.com** ||||
| ojeomneo.ggorockee.com | Ojeomneo Admin | ojeomneo-admin:3000 | ojeomneo |
| api.ojeomneo.ggorockee.com | Ojeomneo API | ojeomneo-server:8000 | ojeomneo |
| **ggorockee.org** ||||
| reviewmaps.ggorockee.org | ReviewMaps | reviewmaps-frontend:3000 | reviewmaps |
| **woohalabs.com** ||||
| argocd.woohalabs.com | ArgoCD | argocd-server:80 | argocd |

## 💰 비용

**무료**:
- ✅ Let's Encrypt 인증서
- ✅ cert-manager (오픈소스)

**Cloud DNS**:
- $0.20/zone/month × 3 zones = **$0.60/month**
- $0.40/million queries

**총 예상 비용**: **~$1-2/month**

## 🔧 트러블슈팅

### Certificate가 Ready 안됨

```bash
# Certificate 상세 정보
kubectl describe certificate <cert-name> -n istio-system

# cert-manager 로그
kubectl logs -n cert-manager -l app=cert-manager --tail=100

# CertificateRequest 확인
kubectl get certificaterequest -n istio-system
```

**일반적인 원인**:
1. Cloud DNS Zone 미생성
2. Service Account 권한 부족
3. DNS 전파 지연 (최대 10분)

### DNS-01 Challenge 실패

```bash
# Cloud DNS Zone 확인
gcloud dns managed-zones list

# TXT 레코드 확인
dig _acme-challenge.ggorockee.com TXT
```

### Istio Gateway 인증서 인식 안됨

```bash
# Secret 확인
kubectl get secret -n istio-system | grep wildcard

# Istio Gateway Pod 재시작
kubectl rollout restart deployment istio-ingressgateway -n istio-system
```

## 📚 참고 문서

- [gcp-ssl-wildcard-certificate.md](./gcp-ssl-wildcard-certificate.md) - 상세 가이드
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)

## ✅ 배포 체크리스트

- [ ] Cloud DNS Zone 생성 (3개)
- [ ] 도메인 등록 업체에서 네임서버 변경
- [ ] DNS A 레코드 추가 (@ 및 *)
- [ ] Terraform apply (cert-manager 모듈)
- [ ] ClusterIssuer 생성
- [ ] Certificate 발급 (3개 도메인)
- [ ] Certificate Ready 확인
- [ ] Istio Gateway HTTPS 설정
- [ ] HTTPS 접속 테스트
- [ ] HTTP → HTTPS 리다이렉트 확인

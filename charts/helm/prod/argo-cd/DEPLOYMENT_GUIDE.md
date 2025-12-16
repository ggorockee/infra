# ArgoCD Deployment Guide - GKE with Dex OIDC

GKE 환경에서 Istio와 ExternalSecrets를 활용한 ArgoCD 배포 가이드

## 아키텍처 개요

```
사용자 → Istio Gateway (TLS) → ArgoCD Server → Dex → Google OAuth
                                      ↓
                              ExternalSecret → Secret Manager
```

- **Helm Chart**: ArgoCD 공식 차트 v9.1.8
- **인증**: Google OAuth 2.0 (Dex OIDC)
- **민감정보**: External Secrets + GCP Secret Manager
- **서비스 메시**: Istio Gateway + VirtualService
- **TLS**: cert-manager wildcard 인증서

## 사전 준비

### 1. Secret Manager 확인

`prod-argocd-dex-credentials` 시크릿 확인:

```bash
gcloud secrets describe prod-argocd-dex-credentials --project=infra-480802
gcloud secrets versions access latest --secret=prod-argocd-dex-credentials --project=infra-480802
```

예상 출력 (JSON):
```json
{
  "google.clientId": "937024223104-xxx.apps.googleusercontent.com",
  "google.clientSecret": "GOCSPX-xxx"
}
```

### 2. Google OAuth 설정 확인

GCP Console → APIs & Services → Credentials

Redirect URIs 확인:
- `https://argocd.ggorockee.com/api/dex/callback`
- `https://argocd.ggorockee.com/auth/callback`

### 3. External Secrets Operator

```bash
kubectl get clustersecretstore gcpsm-secret-store
```

STATUS: Ready 확인

### 4. Istio 설정 확인

```bash
kubectl get gateway main-gateway -n istio-system
kubectl get virtualservice argocd-vs -n argocd
```

## 배포 절차

### Step 1: Feature 브랜치 생성

```bash
cd /home/woohaen88/infra
git checkout -b feature/argocd-dex-oidc
```

### Step 2: 변경사항 확인

추가된 파일:
- `charts/helm/prod/argo-cd/templates/externalsecret-dex.yaml` (ExternalSecret)
- `charts/helm/prod/argo-cd/values-custom.yaml` (Custom values)

수정된 파일:
- `charts/helm/prod/istio-gateway-config/values.yaml` (Rate Limiting 추가)

### Step 3: ArgoCD Helm 업그레이드

```bash
helm upgrade argocd ./charts/helm/prod/argo-cd \
  -f ./charts/helm/prod/argo-cd/values-custom.yaml \
  -n argocd
```

### Step 4: ExternalSecret 동기화 대기

```bash
# ExternalSecret 상태 확인
kubectl get externalsecret argocd-dex-credentials -n argocd

# Secret 생성 확인 (최대 5분 소요)
kubectl get secret argocd-secret -n argocd -o jsonpath='{.data}' | jq 'keys'
```

예상 출력:
```json
[
  "admin.password",
  "admin.passwordMtime",
  "google.clientId",
  "google.clientSecret",
  "server.secretkey"
]
```

### Step 5: ArgoCD Pods 재시작 확인

```bash
kubectl get pods -n argocd
kubectl rollout status deployment argocd-server -n argocd
kubectl rollout status deployment argocd-dex-server -n argocd
```

모든 Pod가 Running 상태 확인

### Step 6: Dex 설정 검증

```bash
# Dex ConfigMap 확인
kubectl get configmap argocd-cm -n argocd -o yaml | grep -A 10 "dex.config"

# Dex Pod 로그 확인
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-dex-server --tail=50
```

정상 로그:
- `config connector "google" configured`
- OAuth provider 연결 성공

### Step 7: Google OAuth 로그인 테스트

브라우저에서 접속:
1. https://argocd.ggorockee.com
2. "LOG IN VIA GOOGLE" 클릭
3. Google 계정 선택
4. 로그인 성공 확인

관리자 이메일로 로그인 시 admin 권한 부여 확인

### Step 8: Git Commit 및 Push

```bash
git add .
git commit -m "feat: Add ArgoCD Dex OIDC with ExternalSecrets integration

- ExternalSecret template for prod-argocd-dex-credentials
- Custom values.yaml with Dex Google OAuth configuration
- Istio Rate Limiting for Dex callback paths
- RBAC policy with admin roles"

git push origin feature/argocd-dex-oidc
```

### Step 9: Pull Request 생성

GitHub에서 PR 생성:
- Base: main
- Compare: feature/argocd-dex-oidc

## 주요 설정 설명

### ExternalSecret 구조

```yaml
# templates/externalsecret-dex.yaml
spec:
  secretStoreRef:
    name: gcpsm-secret-store
    kind: ClusterSecretStore

  target:
    name: argocd-secret
    creationPolicy: Merge  # 기존 Secret에 병합

  dataFrom:
    - extract:
        key: prod-argocd-dex-credentials
```

**핵심**:
- `creationPolicy: Merge`: Helm이 생성한 `argocd-secret`에 Dex 자격증명 추가
- Secret Manager의 JSON을 자동으로 파싱하여 개별 키로 주입

### Dex 설정

```yaml
# values-custom.yaml
configs:
  cm:
    dex.config: |
      connectors:
        - type: google
          config:
            clientID: $argocd-secret:google.clientId
            clientSecret: $argocd-secret:google.clientSecret
```

**ArgoCD Secret 참조 문법**:
- `$<secret-name>:<key>`
- ExternalSecret이 주입한 키를 런타임에 로드

### Istio Rate Limiting

```yaml
# istio-gateway-config/values.yaml
security:
  rateLimit:
    dexCallback:
      enabled: true
      maxTokens: 20
      fillInterval: "60s"
      paths:
        - "/api/dex/callback"
```

**목적**: OAuth callback 경로 브루트 포스 방지

## 검증 체크리스트

- [ ] ExternalSecret STATUS: SecretSynced
- [ ] argocd-secret에 google.clientId, google.clientSecret 키 존재
- [ ] Dex Pod 정상 실행 (Running)
- [ ] Dex 로그에 "config connector google configured" 메시지
- [ ] Google OAuth 로그인 성공
- [ ] 관리자 이메일로 로그인 시 admin 권한 확인
- [ ] Istio VirtualService 정상 작동
- [ ] TLS 인증서 유효

## 트러블슈팅

### 1. ExternalSecret 동기화 실패

**증상**:
```bash
kubectl get externalsecret argocd-dex-credentials -n argocd
# STATUS: SecretSyncedError
```

**원인**:
- IAM 권한 부족
- Secret Manager에 시크릿 없음
- Workload Identity 바인딩 실패

**해결**:
```bash
# IAM 권한 확인
gcloud secrets get-iam-policy prod-argocd-dex-credentials --project=infra-480802

# External Secrets Operator 로그
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets

# ExternalSecret 상세 정보
kubectl describe externalsecret argocd-dex-credentials -n argocd
```

### 2. Dex 인증 실패

**증상**: "Failed to authenticate via dex"

**원인 1**: Redirect URI 불일치

```bash
# Google OAuth Console 설정 확인
# Authorized redirect URIs에 정확히 다음이 포함되어야 함:
# https://argocd.ggorockee.com/api/dex/callback
```

**원인 2**: Client ID/Secret 오류

```bash
# Secret 값 확인
kubectl get secret argocd-secret -n argocd \
  -o jsonpath='{.data.google\.clientId}' | base64 -d

# Google OAuth Console의 값과 일치하는지 확인
```

**원인 3**: DNS 문제

```bash
# Dex Pod에서 Google OAuth에 접근 가능한지 확인
kubectl exec -n argocd -it deploy/argocd-dex-server -- \
  nslookup accounts.google.com
```

### 3. RBAC 권한 문제

**증상**: 로그인 성공하지만 "permission denied"

**해결**:
```bash
# RBAC ConfigMap 확인
kubectl get configmap argocd-rbac-cm -n argocd -o yaml

# policy.csv에 이메일이 포함되어 있는지 확인
# g, your-email@gmail.com, role:admin
```

### 4. Istio Gateway 접속 불가

**증상**: argocd.ggorockee.com 타임아웃

**해결**:
```bash
# VirtualService 확인
kubectl get vs argocd-vs -n argocd

# Gateway 확인
kubectl get gateway main-gateway -n istio-system

# Istio Ingress Gateway Pod 상태
kubectl get pods -n istio-system -l istio=ingressgateway

# DNS 확인
dig argocd.ggorockee.com +short
# → Istio Gateway External IP와 일치해야 함
```

## 보안 권장사항

### 1. Admin Password 변경

초기 admin 비밀번호는 자동 생성됩니다. Google OAuth 설정 후 비활성화 권장:

```yaml
# values-custom.yaml
configs:
  cm:
    admin.enabled: "false"  # Google OAuth만 사용
```

### 2. Session 타임아웃 설정

```yaml
# values-custom.yaml
configs:
  cm:
    dex.config: |
      expiry:
        idTokens: "24h"
        authRequests: "24h"
```

### 3. IP 화이트리스트 (선택)

관리자 경로 IP 제한:

```yaml
# istio-gateway-config/values.yaml
security:
  authorization:
    ipWhitelist:
      enabled: true
      adminPaths:
        - "/settings/*"
      allowedIPs:
        - "YOUR_OFFICE_IP/32"
```

## 참고 자료

- ArgoCD 공식 문서: https://argo-cd.readthedocs.io/
- Dex OIDC Connectors: https://dexidp.io/docs/connectors/google/
- External Secrets: https://external-secrets.io/latest/
- Istio Security: https://istio.io/latest/docs/concepts/security/

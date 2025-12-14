# GCP Istio Service Mesh 배포 가이드

## 개요

GKE Autopilot 클러스터에 Istio Service Mesh를 Helm 차트로 배포하고 ArgoCD로 관리합니다.

**배포 일자**: 2025-12-14
**Istio 버전**: 1.28.1
**배포 방식**: Helm Charts via ArgoCD ApplicationSet

## 아키텍처

### Istio 컴포넌트

| 컴포넌트 | 차트 | 네임스페이스 | 역할 |
|----------|------|-------------|------|
| **istio-base** | `istio/base v1.28.1` | istio-system | CRDs 및 클러스터 리소스 |
| **istiod** | `istio/istiod v1.28.1` | istio-system | 제어 평면 (Pilot, Citadel, Galley) |
| **istio-ingressgateway** | `istio/gateway v1.28.1` | istio-system | Ingress Gateway (외부 트래픽) |

### 배포 구조

```
infra/
├── charts/helm/prod/istio-system/
│   ├── istio-base/
│   │   ├── Chart.yaml        # base v1.28.1
│   │   └── values.yaml       # CRD 설정
│   ├── istiod/
│   │   ├── Chart.yaml        # istiod v1.28.1
│   │   └── values.yaml       # Control Plane 설정
│   └── istio-ingressgateway/
│       ├── Chart.yaml        # gateway v1.28.1
│       └── values.yaml       # Gateway 설정
└── argocd_yaml/
    └── prod-applicationsets-gitchart.yaml  # ApplicationSet
```

## 배포 현황

### ArgoCD Applications

```
kubectl get applications -n argocd
```

| Application | Sync Status | Health Status |
|-------------|-------------|---------------|
| istio-base | Synced | Healthy |
| istiod | Synced | Healthy |
| istio-ingressgateway | Synced | Healthy |

### Kubernetes Resources

```
kubectl get pods -n istio-system
```

| Pod | Ready | Status | Image |
|-----|-------|--------|-------|
| istiod-* | 1/1 | Running | docker.io/istio/pilot:1.28.1 |
| istio-ingressgateway-* | 1/1 | Running | docker.io/istio/proxyv2:1.28.1 |

### Services

```
kubectl get svc -n istio-system
```

| Service | Type | ClusterIP | External IP | Ports |
|---------|------|-----------|-------------|-------|
| istiod | ClusterIP | 34.118.228.208 | - | 15010, 15012, 443, 15014 |
| istio-ingressgateway | LoadBalancer | 34.118.236.32 | **34.50.12.202** | 15021, 80, 443 |

## Helm Values 설정

### istio-base

**주요 설정**:
- `global.istioNamespace`: istio-system
- `base.enableCRDTemplates`: true
- `base.enableIstioConfigCRDs`: true

### istiod

**주요 설정**:
- `global.hub`: docker.io/istio
- `global.tag`: 1.28.1
- `global.proxy.resources`: CPU 100m-2000m, Memory 128Mi-1024Mi
- `autoscaleEnabled`: true (1-5 replicas)
- `meshConfig.enablePrometheusMerge`: true
- `telemetry.v2.prometheus.enabled`: true

### istio-ingressgateway

**주요 설정**:
- `replicaCount`: 2
- `service.type`: LoadBalancer
- `autoscaling.enabled`: true (2-5 replicas)
- `labels.istio`: ingressgateway (Gateway selector용)
- `global.networkPolicy.enabled`: false

## ArgoCD ApplicationSet 설정

**패턴**: `charts/helm/prod/*/*`

**자동 생성 규칙**:
- **App Name**: `{{path.basename}}`
- **Namespace**: `{{path[3]}}`

**Sync Policy**:
- `automated.prune`: true
- `automated.selfHeal`: true
- `syncOptions`: CreateNamespace=true

**ignoreDifferences**:
- ValidatingWebhookConfiguration (Istio)
- Service (clusterIP, allocateLoadBalancerNodePorts)
- DaemonSet (hostNetwork, extraVolumeMounts)

## 트러블슈팅 이력

### Issue 1: Helm 차트 스키마 검증 오류

**오류**:
```
Error: values don't meet the specifications of the schema(s):
gateway: - env: Invalid type. Expected: object, given: array
```

**원인**: gateway 차트는 `env`를 객체로 요구하는데 배열로 설정

**해결**: `env: []` → `env: {}`

### Issue 2: NetworkPolicy 템플릿 오류

**오류**:
```
nil pointer evaluating interface {}.networkPolicy
```

**원인**: gateway 차트 템플릿이 `.Values.global.networkPolicy` 참조

**해결**: `global.networkPolicy.enabled: false` 추가

### Issue 3: Service OutOfSync

**원인**: LoadBalancer Service의 자동 할당 필드 (clusterIP 등)

**해결**: ApplicationSet ignoreDifferences에 Service 필드 추가

## 다음 단계

### Gateway 리소스 생성

Istio Gateway를 생성하여 외부 트래픽을 수신:

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "*"
    tls:
      mode: SIMPLE
      credentialName: tls-cert
```

### VirtualService 설정

애플리케이션 라우팅 규칙 정의:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: app-route
spec:
  hosts:
  - "app.example.com"
  gateways:
  - main-gateway
  http:
  - route:
    - destination:
        host: app-service
        port:
          number: 80
```

### Sidecar Injection 활성화

네임스페이스에 Istio sidecar 자동 주입:

```bash
kubectl label namespace <namespace> istio-injection=enabled
```

## 참고 문서

- [Istio 1.28.1 Release Notes](https://istio.io/latest/news/releases/1.28.x/announcing-1.28.1/)
- [Istio Helm Installation](https://istio.io/latest/docs/setup/install/helm/)
- [Gateway Configuration](https://istio.io/latest/docs/setup/additional-setup/gateway/)
- [VirtualService Guide](https://istio.io/latest/docs/reference/config/networking/virtual-service/)

## 외부 접속 정보

**Istio Ingress Gateway LoadBalancer IP**: `34.50.12.202`

**테스트 방법**:
```bash
curl http://34.50.12.202
# 또는
curl http://34.50.12.202 -H "Host: your-app.example.com"
```

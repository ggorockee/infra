# GKE BackendConfig Helm Chart

GKE BackendConfig for Istio Ingress Gateway with CloudArmor integration.

## Overview

This chart creates a BackendConfig resource that connects CloudArmor security policy to the GKE Load Balancer behind Istio Ingress Gateway.

## Prerequisites

- GKE cluster with Istio installed
- CloudArmor security policy created via Terraform
- Istio Ingress Gateway Service running in istio-system namespace

## Installation

### 1. Deploy BackendConfig via ArgoCD

BackendConfig resource is automatically deployed via ArgoCD.

### 2. Manually Patch Istio Ingress Gateway Service

After deploying the BackendConfig, you need to manually add annotations to the Istio Ingress Gateway Service:

```bash
kubectl patch svc istio-ingressgateway -n istio-system -p '{"metadata":{"annotations":{"cloud.google.com/backend-config":"{\"default\": \"istio-ingress-backendconfig\"}","beta.cloud.google.com/backend-config":"{\"default\": \"istio-ingress-backendconfig\"}"}}}'
```

### 3. Verify BackendConfig Attachment

Check if the BackendConfig annotation is properly attached:

```bash
kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.metadata.annotations}'
```

Expected output should include:
```json
{
  "cloud.google.com/backend-config": "{\"default\": \"istio-ingress-backendconfig\"}",
  "beta.cloud.google.com/backend-config": "{\"default\": \"istio-ingress-backendconfig\"}"
}
```

### 4. Verify CloudArmor Integration

Check if CloudArmor policy is applied to the Load Balancer backend:

```bash
# Get Load Balancer backend service name
kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Check backend service in GCP Console
gcloud compute backend-services list --filter="loadBalancingScheme:EXTERNAL"
```

## Configuration

### values.yaml

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.name` | Target service name | `istio-ingressgateway` |
| `service.namespace` | Target service namespace | `istio-system` |
| `backendConfig.name` | BackendConfig resource name | `istio-ingress-backendconfig` |
| `cloudArmor.enabled` | Enable CloudArmor integration | `true` |
| `cloudArmor.securityPolicy` | CloudArmor policy name | `prod-gke-istio-security-policy` |
| `healthCheck.checkIntervalSec` | Health check interval | `10` |
| `healthCheck.timeoutSec` | Health check timeout | `5` |
| `healthCheck.healthyThreshold` | Healthy threshold | `2` |
| `healthCheck.unhealthyThreshold` | Unhealthy threshold | `3` |
| `healthCheck.type` | Health check type | `HTTP` |
| `healthCheck.port` | Health check port | `15021` |
| `healthCheck.requestPath` | Health check path | `/healthz/ready` |
| `connectionDraining.drainingTimeoutSec` | Connection draining timeout | `60` |
| `sessionAffinity.enabled` | Enable session affinity | `false` |
| `sessionAffinity.affinityType` | Session affinity type | `CLIENT_IP` |
| `sessionAffinity.affinityCookieTtlSec` | Session affinity cookie TTL | `3600` |

## Why Manual Service Patching?

Helm cannot directly patch existing Kubernetes resources that are managed by other Helm charts (Istio Gateway chart in this case). Therefore, the Service annotation must be applied manually via `kubectl patch`.

## Troubleshooting

### BackendConfig not taking effect

1. Check if BackendConfig resource exists:
```bash
kubectl get backendconfig -n istio-system
```

2. Verify Service annotations:
```bash
kubectl get svc istio-ingressgateway -n istio-system -o yaml | grep -A2 annotations
```

3. Check GKE Load Balancer backend service:
```bash
gcloud compute backend-services describe [BACKEND_SERVICE_NAME] --global
```

### CloudArmor policy not applied

1. Verify CloudArmor policy exists:
```bash
gcloud compute security-policies describe prod-gke-istio-security-policy
```

2. Check backend service security policy:
```bash
gcloud compute backend-services describe [BACKEND_SERVICE_NAME] --global | grep securityPolicy
```

## Uninstallation

1. Remove annotations from Service:
```bash
kubectl annotate svc istio-ingressgateway -n istio-system cloud.google.com/backend-config- beta.cloud.google.com/backend-config-
```

2. Delete BackendConfig via ArgoCD or manually:
```bash
kubectl delete backendconfig istio-ingress-backendconfig -n istio-system
```

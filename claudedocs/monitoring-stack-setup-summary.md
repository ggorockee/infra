# 모니터링 스택 설정 완료 요약

최종 업데이트: 2025-12-17

## 완료된 작업

### 1. Helm Values 커스터마이징

**파일**: [charts/helm/prod/kube-prometheus-stack/values-override.yaml](../charts/helm/prod/kube-prometheus-stack/values-override.yaml)

**주요 설정**:
- Grafana OAuth (Google) 연동
- PVC 설정 (Grafana 10Gi, Prometheus 30Gi, Alertmanager 5Gi)
- 도메인 설정 (grafana.ggorockee.com, prom.ggorockee.com)
- Storage Class: standard-rwo (GCP Persistent Disk)

### 2. External Secret 설정

**파일**: [charts/helm/prod/kube-prometheus-stack/templates/grafana-external-secret.yaml](../charts/helm/prod/kube-prometheus-stack/templates/grafana-external-secret.yaml)

**용도**: GCP Secret Manager에서 OAuth credentials 자동 동기화
- Secret: `prod-argocd-dex-credentials`
- 포함 항목: google.clientId, google.clientSecret

### 3. Istio VirtualService 추가

**파일**: [charts/helm/prod/istio-gateway-config/values.yaml](../charts/helm/prod/istio-gateway-config/values.yaml)

**추가된 VirtualService**:
- `grafana-vs`: grafana.ggorockee.com → kube-prometheus-stack-grafana:80
- `prometheus-vs`: prom.ggorockee.com → kube-prometheus-stack-prometheus:9090

### 4. ArgoCD 설정 업데이트

**파일**: [charts/argocd/configurations/prod/monitoring-prom-grafana-cfg.yaml](../charts/argocd/configurations/prod/monitoring-prom-grafana-cfg.yaml)

**변경사항**: values-override.yaml 참조 추가

## 아직 필요한 작업

### 1. External Secrets Operator 설치

**현재 상태**: 미설치

**필요 작업**:
```bash
# Helm으로 설치
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --set installCRDs=true
```

**확인 방법**:
```bash
kubectl get pods -n external-secrets-system
kubectl get crd | grep external-secrets
```

### 2. ClusterSecretStore 생성

**파일**: [charts/helm/prod/kube-prometheus-stack/external-secrets/cluster-secret-store.yaml](../charts/helm/prod/kube-prometheus-stack/external-secrets/cluster-secret-store.yaml)

**필요 수정**:
1. `YOUR_GCP_PROJECT_ID`를 실제 GCP 프로젝트 ID로 변경
2. Workload Identity 설정 확인

**적용 방법**:
```bash
# 파일 수정 후
kubectl apply -f charts/helm/prod/kube-prometheus-stack/external-secrets/cluster-secret-store.yaml

# 확인
kubectl get clustersecretstore gcpsm-secret-store -o yaml
```

### 3. GCP Workload Identity 설정

**필요 작업**:
```bash
# GCP Service Account 생성
gcloud iam service-accounts create external-secrets \
  --display-name="External Secrets Operator"

# Secret Manager 권한 부여
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:external-secrets@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Workload Identity 바인딩
gcloud iam service-accounts add-iam-policy-binding \
  external-secrets@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:YOUR_PROJECT_ID.svc.id.goog[external-secrets-system/external-secrets-sa]"
```

### 4. DNS 레코드 설정

**필요한 DNS A 레코드**:

| 도메인 | 타입 | 값 |
|--------|------|-----|
| grafana.ggorockee.com | A | [Istio Ingress IP] |
| prom.ggorockee.com | A | [Istio Ingress IP] |

**Istio Ingress IP 확인**:
```bash
kubectl get svc -n istio-system istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**GCP Cloud DNS 설정** (Terraform 권장):
```bash
# gcp/terraform/environments/prod/dns.tf 에 추가
resource "google_dns_record_set" "grafana" {
  name         = "grafana.ggorockee.com."
  type         = "A"
  ttl          = 300
  managed_zone = "ggorockee-com"
  rrdatas      = [var.istio_ingress_ip]
}

resource "google_dns_record_set" "prometheus" {
  name         = "prom.ggorockee.com."
  type         = "A"
  ttl          = 300
  managed_zone = "ggorockee-com"
  rrdatas      = [var.istio_ingress_ip]
}
```

## 배포 순서

### 1단계: 사전 요구사항 설치
- [ ] External Secrets Operator 설치
- [ ] GCP Workload Identity 설정
- [ ] ClusterSecretStore 생성 및 확인

### 2단계: Git 커밋 및 푸시
```bash
git add charts/helm/prod/kube-prometheus-stack/values-override.yaml
git add charts/helm/prod/kube-prometheus-stack/templates/grafana-external-secret.yaml
git add charts/helm/prod/kube-prometheus-stack/external-secrets/
git add charts/helm/prod/kube-prometheus-stack/DEPLOYMENT-GUIDE.md
git add charts/helm/prod/istio-gateway-config/values.yaml
git add charts/argocd/configurations/prod/monitoring-prom-grafana-cfg.yaml

git commit -m "feat: Prometheus & Grafana 모니터링 스택 설정 추가

- Grafana Google OAuth 연동 (Dex credentials)
- PVC 설정 (Grafana 10Gi, Prometheus 30Gi)
- External Secret으로 OAuth credentials 동기화
- Istio VirtualService 추가 (grafana/prom.ggorockee.com)
- Storage Class: standard-rwo (GCP Persistent Disk)"

git push origin feature/add-monitoring-stack
```

### 3단계: DNS 레코드 추가
- [ ] Istio Ingress IP 확인
- [ ] GCP Cloud DNS에 A 레코드 추가 (Terraform 권장)

### 4단계: ArgoCD 자동 배포
- ArgoCD가 자동으로 변경사항을 감지하여 배포
- ApplicationSet이 monitoring-prom-grafana-cfg.yaml 기반으로 배포

### 5단계: 배포 확인
```bash
# Namespace 생성 확인
kubectl get ns monitoring

# Pod 상태 확인
kubectl get pods -n monitoring

# PVC 생성 확인
kubectl get pvc -n monitoring

# External Secret 동기화 확인
kubectl get externalsecret -n monitoring

# VirtualService 생성 확인
kubectl get virtualservice -n monitoring
```

### 6단계: 접속 테스트
- [ ] https://grafana.ggorockee.com 접속
- [ ] Google OAuth 로그인 테스트
- [ ] https://prom.ggorockee.com 접속 확인

## 스토리지 및 비용

### PVC 용량

| 컴포넌트 | 용량 | Storage Class | 월 비용 (예상) |
|---------|------|---------------|----------------|
| Grafana | 10Gi | standard-rwo | ~$1.6 |
| Prometheus | 30Gi | standard-rwo | ~$4.8 |
| Alertmanager | 5Gi | standard-rwo | ~$0.8 |
| **합계** | **45Gi** | - | **~$7.2** |

*GCP Standard Persistent Disk 기준 ($0.16/GB/월)*

### 비용 최적화 옵션

**옵션 1: Retention 단축**
- Prometheus retention: 15일 → 7일
- 스토리지 요구량: 30Gi → 15Gi
- 절감 비용: ~$2.4/월

**옵션 2: Scrape Interval 증가**
- Scrape interval: 30초 → 60초
- 메트릭 양: 50% 감소
- 스토리지 요구량: 30Gi → 20Gi
- 절감 비용: ~$1.6/월

## OAuth 설정 상세

### Google OAuth Credentials

**GCP Secret Manager**:
- Secret 이름: `prod-argocd-dex-credentials`
- 포함 정보:
  - `google.clientId`: <YOUR_GOOGLE_OAUTH_CLIENT_ID>
  - `google.clientSecret`: <YOUR_GOOGLE_OAUTH_CLIENT_SECRET>
  - `admin.emails`: woohaen88@gmail.com, woohalabs@gmail.com, ggorockee@gmail.com

### 관리자 권한

다음 이메일은 자동으로 Admin 권한 부여:
- woohaen88@gmail.com
- woohalabs@gmail.com
- ggorockee@gmail.com

그 외 Gmail 사용자는 Viewer 권한으로 로그인

## 트러블슈팅

### External Secret이 생성되지 않음

**원인**: ClusterSecretStore가 올바르게 설정되지 않음

**확인**:
```bash
kubectl get clustersecretstore gcpsm-secret-store -o yaml
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets
```

### Grafana 접속 불가

**원인 1**: DNS 레코드 미설정
```bash
nslookup grafana.ggorockee.com
```

**원인 2**: VirtualService 미생성
```bash
kubectl get virtualservice -n monitoring grafana-vs -o yaml
```

**원인 3**: Pod 비정상
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### PVC가 Pending 상태

**원인**: Storage Class가 WaitForFirstConsumer 모드

**해결**: Pod가 생성되면 자동으로 Bound 상태로 변경됨
```bash
kubectl get pvc -n monitoring -w
```

## 참고 자료

- [Prometheus Operator 공식 문서](https://prometheus-operator.dev/)
- [Grafana OAuth 설정](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/google/)
- [External Secrets Operator](https://external-secrets.io/latest/provider/google-secrets-manager/)
- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)

## 다음 단계

배포 완료 후:
1. [ ] Grafana 대시보드 커스터마이징
2. [ ] Alertmanager 알림 채널 설정 (Slack, Email 등)
3. [ ] ServiceMonitor 추가 (애플리케이션 메트릭 수집)
4. [ ] Recording Rules 최적화 (쿼리 성능 개선)
5. [ ] 백업 전략 수립 (Grafana 대시보드, Prometheus 설정)

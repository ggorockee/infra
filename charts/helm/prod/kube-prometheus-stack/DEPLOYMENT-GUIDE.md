# Kube-Prometheus-Stack 배포 가이드

## 개요

Prometheus, Grafana, Alertmanager를 포함한 모니터링 스택 배포

## 주요 구성 요소

| 컴포넌트 | 도메인 | 설명 |
|---------|--------|------|
| Grafana | grafana.ggorockee.com | 대시보드 및 시각화 |
| Prometheus | prom.ggorockee.com | 메트릭 수집 및 저장 |
| Alertmanager | (내부 전용) | 알림 관리 |

## 사전 요구사항

### 1. External Secrets Operator 설치

GCP Secret Manager에서 OAuth credentials를 가져오기 위해 필요합니다.

### 2. ClusterSecretStore 생성

GCP Secret Manager 연동용 ClusterSecretStore가 필요합니다.

### 3. DNS 레코드 설정

GCP Cloud DNS에 A 레코드 추가:
- `grafana.ggorockee.com` → Istio Ingress Gateway IP
- `prom.ggorockee.com` → Istio Ingress Gateway IP

## 스토리지 설정

### PVC 용량 (1인 개발자용)

| 컴포넌트 | 용량 | Storage Class | 용도 |
|---------|------|---------------|------|
| Grafana | 10Gi | standard-rwo | 대시보드, 플러그인 |
| Prometheus | 30Gi | standard-rwo | 메트릭 데이터 (15일) |
| Alertmanager | 5Gi | standard-rwo | 알림 데이터 |

**총 비용**: 약 $7/월 (GCP Standard Persistent Disk)

## OAuth 설정

### Google OAuth 인증

GCP Secret Manager에서 자동 로드:
- Secret: `prod-argocd-dex-credentials`
- 관리자: woohaen88@gmail.com, woohalabs@gmail.com, ggorockee@gmail.com

## 배포 방법

ArgoCD가 자동으로 배포합니다.

## 접속 방법

### Grafana

1. https://grafana.ggorockee.com 접속
2. "Sign in with Google" 클릭
3. Gmail 로그인

### Prometheus

- https://prom.ggorockee.com

## 주요 설정 파일

- `values-override.yaml`: Helm values 커스터마이징
- `templates/grafana-external-secret.yaml`: OAuth Secret 동기화
- `../istio-gateway-config/values.yaml`: Istio VirtualService

## 비용 최적화

- Retention: 15일 (필요 시 7일로 단축)
- Scrape interval: 30초 (필요 시 60초로 변경)
- Standard Disk 사용 (Premium SSD 대신)

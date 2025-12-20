# Woohalabs App-Ads.txt Helm Chart

## 개요

`woohalabs.com/app-ads.txt` 경로로 Google AdSense app-ads.txt 파일을 서빙하는 간단한 nginx 웹서버 Helm 차트입니다.

## 구성 요소

- **Deployment**: nginx 1.27-alpine 기반 Pod (replica: 2)
- **Service**: ClusterIP 타입 (포트: 80)
- **ConfigMap**: app-ads.txt 파일 및 nginx 설정

## 배포된 리소스

| 리소스 타입 | 이름 | 설명 |
|------------|------|------|
| Deployment | woohalabs-app-ads | nginx 컨테이너 2 replica |
| Service | woohalabs-app-ads | ClusterIP:80 |
| ConfigMap | woohalabs-app-ads | app-ads.txt + nginx config |

## app-ads.txt 내용

`woohalabs.com/app-ads.txt` 접근 시 다음 내용이 반환됩니다:

```
google.com, pub-8516861197467665, DIRECT, f08c47fec0942fa0
```

## Istio VirtualService 설정

`istio-gateway-config/values.yaml`에 다음과 같이 설정되어 있습니다:

| 설정 항목 | 값 |
|---------|-----|
| 호스트 | woohalabs.com |
| 경로 | /app-ads.txt (exact match) |
| 대상 서비스 | woohalabs-app-ads:80 |
| 네임스페이스 | woohalabs-app-ads |

## 리소스 사용량

| 리소스 | Request | Limit |
|--------|---------|-------|
| CPU | 50m | 100m |
| Memory | 64Mi | 128Mi |

## Health Check

- **Liveness Probe**: `GET /app-ads.txt` (10초 간격)
- **Readiness Probe**: `GET /app-ads.txt` (5초 간격)

## ArgoCD 배포

ArgoCD를 통해 자동 배포됩니다:

- **설정 파일**: `charts/argocd/configurations/prod/apps-woohalabs-app-ads-cfg.yaml`
- **네임스페이스**: woohalabs-app-ads
- **Git 브랜치**: main

## 로컬 테스트

nginx 설정 검증:

`nginx -t -c charts/helm/prod/woohalabs-app-ads/templates/configmap.yaml`

## 주의사항

- **경로 정확성**: `/app-ads.txt` exact match만 허용 (다른 경로는 404 반환)
- **다른 서비스 영향 없음**: woohalabs.com의 다른 경로는 기존 VirtualService가 처리
- **우선순위**: Istio VirtualService의 match 순서에 따라 `/app-ads.txt`가 우선 매칭됨

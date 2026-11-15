# 오점너 서비스 중지 (2026-11-15)

이 차트는 재개를 위해 보존한다. 현재 ArgoCD에 배포되지 않는다.

| 항목 | 상태 |
|------|------|
| ArgoCD 앱 | 삭제 (`charts/argocd/configurations/prod/apps-ojeomneo-cfg.yaml` 제거) |
| 보존 데이터 | Cloud SQL `ojeomneo` DB, GSM `prod-ojeomneo-*` 시크릿 4개, Redis 디스크(PV Retain) |
| 재개 방법 | `claudedocs/ojeomneo-shutdown.md` 6장 |

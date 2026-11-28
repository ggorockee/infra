# OpenTelemetry·SigNoz 남은 설정 정리

**OpenTelemetry(otel-collector)와 SigNoz는 사용하지 않는다** (2026-11-28 개발자 확인). 2026-11-13 모니터링을 Prometheus·Grafana로 다시 만들며 서버 쪽은 제거했지만, 앱 설정과 코드에는 남아 있다. 2026-11-28에 정리하기로 했다.

## 실제 영향이 있는 것

| 위치 | 내용 | 영향 |
|---|---|---|
| infra `charts/helm/prod/reviewmaps/charts/go-scraper/values.yaml` 48행 | `SIGNOZ_ENDPOINT`가 없는 주소 `otel-collector.monitoring.svc.cluster.local:4318`를 가리킴 | 리뷰맵 CronJob 5개(inflexer, reviewnote, reviewnote-detail, pickly, cleanup)가 실행되는 동안 30초마다 전송 실패 로그, 끝날 때 경고 한 줄. 수집과 Pushgateway 지표에는 영향 없음 |

## 해야 할 일 (2026-11-28)

| 상태 | 순서 | 할 일 |
|---|---|---|
| [x] | 1 | 위 `SIGNOZ_ENDPOINT` 줄 삭제 (중지 중인 `hotsao` 차트의 같은 줄도) → PR → 머지. 수집기 코드는 주소가 없으면 아무것도 보내지 않아 이미지 빌드는 필요 없음 |
| [x] | 2 | ArgoCD Synced 확인, `kubectl -n reviewmaps get cm`에서 `SIGNOZ_ENDPOINT`가 사라졌는지 확인 |
| [x] | 3 | 반영 뒤 새로 시작한 Job 로그에 `otel-collector` 줄이 없는지 확인. 실행 중이던 Job은 시작할 때의 환경 변수를 그대로 씀 |

확인 결과 (2026-11-28): infra #1246으로 주소 삭제, 저장소 `charts`와 리뷰맵 ConfigMap에 `SIGNOZ_ENDPOINT` 없음, ArgoCD Synced/Healthy, 반영 뒤 시작한 상세·목록 Job 로그에 전송 관련 줄 0.

## 동작에는 영향 없는 잔여 (지울지 개발자 결정)

| 위치 | 내용 |
|---|---|
| reviewmaps `server/internal/telemetry/`, `server/cmd/api/main.go`, `server/internal/config/config.go`, `server/go.mod` | 주소(`SIGNOZ_ENDPOINT`)가 설정돼 있지 않아 비활성. 운영 설정에도 없음 |
| reviewmaps `go-scraper/internal/telemetry/`, `go-scraper/go.mod` | 주소가 없으면 비활성. 호출 코드가 수집기 곳곳에 있어 제거하려면 코드 수정·테스트·이미지 빌드 필요 |
| reviewmaps `docker-compose.yml`, `server/.env.example` | 로컬 개발용 SigNoz 수집기와 예시 값 |
| infra `charts/helm/prod/ojeomneo/values.yaml` | 중지된 서비스 |
| infra `charts/argocd/applicationsets/valuefiles/prod/traefik-routes/values.yaml` | `signoz` 라우트. 이 앱의 ApplicationSet 설정 파일이 없어 배포되지 않음 |
| infra `aws/terraform/1.observerbility/` | 옛 AWS 실습용 코드 |

돌려받엔·라익찍스 저장소에서는 발견되지 않았다 (git 추적 파일 검색, 문서 제외).

# 오점너(ojeomneo) 서비스 중지

중지일: 2026-11-15 / 방식: 클러스터에서 제거, 데이터 보존 (재개 가능)

## 1. 요약

| 영역 | 조치 | 되돌릴 수 있나 |
|------|------|---------------|
| 모니터링·알림 | 오점너 알림 4개·수집 2개·접속 검사 4개·대시보드 제거 | 가능 (git 이력) |
| 클러스터 | ArgoCD 앱 `ojeomneo` 삭제 (Pod·Service·ExternalSecret 삭제), VirtualService 3개 비활성화 | 가능 (6장) |
| Gemini (Google AI) | API 키 삭제, Generative Language API 비활성화, 결제 연결 해제 | 키는 2026-12-15까지만 복구 가능, 나머지는 가능 |
| Firebase `ojeomneo-e7f17` | 변경 없음 (무료 플랜, 결제 미연결) | - |
| 데이터 | 전부 보존 (3장) | - |

## 2. 작업 순서와 PR

서비스를 먼저 내리면 OjeomneoServerDown·ServiceEndpointDown [CRITICAL] 메일이 발생하므로 모니터링을 먼저 껐다.

| 순서 | PR | 내용 |
|------|----|------|
| 1 | infra #1161 | 모니터링 제거: 알림 apps.ojeomneo(OjeomneoServerDown, OjeomneoDBPoolExhausted), database.redis(오점너 Redis exporter 전용 2개). ServiceMonitor ojeomneo-server·ojeomneo-redis. blackbox ojeomneo-api·web·admin·redis. DB 규칙·대시보드 대상을 reviewmaps로 한정. `ojeomneo-dashboard.json` 삭제 |
| 2 | infra #1162 | `charts/argocd/configurations/prod/apps-ojeomneo-cfg.yaml` 삭제 → ApplicationSet이 앱 삭제 (resources-finalizer로 리소스 함께 삭제). 차트에 `STOPPED.md` 추가 |
| 3 | infra #1163 | VirtualService 3개(`ojeomneo-admin-vs`, `ojeomneo-api-vs`, `ojeomneo-web-vs`)를 `istio-gateway-config` values에서 `enabled: false`. 앱 삭제 후에도 이 차트가 따로 관리해 남아 있었고 503을 반환함 |
| 4 | (gcloud) | Gemini 프로젝트 조치 (4장) |

중지 후 확인 결과:

| 주소 | 응답 |
|------|------|
| api.woohalabs.com/ojeomneo/…, admin.woohalabs.com/ojeomneo/, woohalabs.com/ojeomneo | 404 |
| woohalabs.com/ (예전에는 /ojeomneo로 리다이렉트) | 404 |
| woohalabs.com/app-ads.txt, www.woohalabs.com/app-ads.txt | 200 (유지) |
| 리뷰맵 (review-maps.com, api.review-maps.com) | 200 (영향 없음) |
| ArgoCD 앱 전체 | Synced/Healthy |
| 전환 중 알림 | 오탐 없음 (배포 완료 INFO만) |

## 3. 보존한 자원

| 자원 | 위치 | 비고 |
|------|------|------|
| Helm 차트 | `charts/helm/prod/ojeomneo` (`STOPPED.md` 참고) | 배포 안 됨 |
| DB | Cloud SQL `prod-woohalabs-cloudsql` / DB `ojeomneo` (약 8.8MiB) | 리뷰맵과 같은 인스턴스, 추가 비용 없음 |
| Secret | GSM `prod-ojeomneo-admin-credentials`, `prod-ojeomneo-api-credentials`, `prod-ojeomneo-db-credentials`, `prod-ojeomneo-redis-credentials` (프로젝트 yanggo-514212) | api-credentials 안의 `GEMINI_API_KEY`는 삭제된 키라 더 이상 동작하지 않음 |
| Redis 디스크 | PVC `ojeomneo/redis-data-ojeomneo-redis-master-0` (1Gi, PV Retain) | 월 약 $0.04 |
| 네임스페이스 | `ojeomneo` (PVC만 남음) | PVC 보존 때문에 유지 |
| Firebase | 프로젝트 `ojeomneo-e7f17` (번호 9000418106) | 무료 플랜. 서비스 계정 `firebase-adminsdk-fbsvc`와 모바일 앱 키 3개 그대로 |
| woohalabs.com 인증서·Gateway 설정 | `istio-system/woohalabs-com-wildcard-cert` | app-ads.txt가 사용 |

## 4. Google 쪽 조치 (Gemini)

Gemini 키가 속한 프로젝트는 처음에 프로젝트 번호(117398995616)만 보였다. 이 PC에 로그인된 계정 중 `woohalabs@gmail.com`으로 조회해서 확인했다.

| 항목 | 값 |
|------|-----|
| 프로젝트 ID | `gen-lang-client-0107981418` (Google AI Studio가 Gemini 키 발급 시 자동 생성) |
| 표시 이름 / 번호 | `ojeomneo` / 117398995616 |
| 소유자 | woohalabs@gmail.com |
| 결제 계정 | 017934-216445-4FDEBF (해제 전) |

| 조치 | 명령 (계정 `--account=woohalabs@gmail.com`) | 결과 |
|------|--------------------------------------------|------|
| API 키 `ojeomneo-gemini` 삭제 | `gcloud services api-keys delete <키 ID> --project gen-lang-client-0107981418` | 삭제됨 (2026-11-15). 30일 안에 `gcloud services api-keys undelete`로 복구 가능 |
| Generative Language API 비활성화 | `gcloud services disable generativelanguage.googleapis.com --project gen-lang-client-0107981418` | 비활성화됨 (남은 API: telemetry) |
| 결제 연결 해제 | `gcloud billing projects unlink gen-lang-client-0107981418` | billingEnabled false. 첫 시도는 네트워크 오류로 실패해 재시도 |

Firebase `ojeomneo-e7f17`은 결제가 연결되지 않은 무료 플랜이라 비용 위험이 없어 그대로 두었다. 필요하면 서비스 계정 비활성화(`gcloud iam service-accounts disable firebase-adminsdk-fbsvc@ojeomneo-e7f17.iam.gserviceaccount.com`) 또는 콘솔에서 프로젝트 종료(30일 후 영구 삭제)를 할 수 있다.

계정 참고: 기본 gcloud 계정(woohalabs11@gmail.com)은 두 프로젝트 모두 권한이 없다. 오점너 Google 자원은 woohalabs@gmail.com 소유다.

## 5. 오점너가 쓰던 다른 외부 키 (이번에 변경하지 않음)

GSM `prod-ojeomneo-api-credentials`에 들어 있는 키다. Google이 아니어서 이번 범위에서 제외했다. 비용이나 유출이 걱정되면 각 서비스 콘솔에서 폐기한다.

| 키 | 서비스 |
|----|--------|
| `OPENAI_API_KEY` | OpenAI (사용량 과금) |
| `KAKAO_REST_API_KEY` | 카카오 로그인 |
| `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_TEAM_ID` | Apple 로그인 |
| `CLOUDFLARE_API_KEY`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_ACCOUNT_HASH` | Cloudflare Images |
| `EMAIL_HOST_*` | 메일 발송 |

## 6. 재개 절차

| 순서 | 작업 |
|------|------|
| 1 | Gemini: `gen-lang-client-0107981418`에 결제 다시 연결, `generativelanguage.googleapis.com` 활성화, 새 키 발급 (또는 2026-12-15 전이면 기존 키 undelete) |
| 2 | 새 Gemini 키를 GSM `prod-ojeomneo-api-credentials`의 `GEMINI_API_KEY`에 반영 (새 버전 추가, gcloud 쓰기 → 승인 필요) |
| 3 | `charts/argocd/configurations/prod/apps-ojeomneo-cfg.yaml` 복구 (git 이력 #1162 이전), 차트의 `STOPPED.md` 삭제 |
| 4 | `charts/helm/prod/istio-gateway-config/values.yaml`에서 VirtualService 3개 `enabled: true` |
| 5 | 모니터링 복구: #1161 변경 되돌리기 (알림 규칙, ServiceMonitor, blackbox 대상, 대시보드) — 서비스가 뜬 뒤에 반영해야 [CRITICAL] 오탐이 없음 |
| 6 | Redis는 보존된 PVC를 StatefulSet이 그대로 다시 사용 (이름 동일) |

## 7. 남은 정리 (선택)

- [x] 예전 대시보드 `database-performance`, `systems-overview` 삭제 (2026-11-28, `claudedocs/monitoring-audit-2026-11-28.md`)
- [ ] 완전히 접을 경우: Cloud SQL `ojeomneo` DB, GSM 시크릿 4개, Redis PV, 차트 디렉터리, Firebase 프로젝트, Gemini 프로젝트 삭제
- [ ] 5장 외부 키(OpenAI 등) 폐기 여부 결정
- [ ] 스토어에 배포된 오점너 모바일 앱 처리 (API가 404를 반환하는 상태)

## 8. 작업 체크리스트

- [x] 오점너 구성·외부 키·Google 프로젝트 조사
- [x] 모니터링·알림 제거 (#1161), 오탐 없음 확인
- [x] ArgoCD 앱 삭제 (#1162), Pod·Service·Secret 삭제 확인
- [x] VirtualService 비활성화 (#1163), 오점너 주소 404·app-ads.txt 200·리뷰맵 200 확인
- [x] 보존 자원 확인 (DB, GSM 시크릿 4개, Redis PVC)
- [x] Gemini 키 삭제, API 비활성화, 결제 해제 확인
- [x] 문서 작성, CLAUDE.md·모니터링 문서 갱신

# 앱·광고·스토어 모니터링

작성일: 2026-11-26 · 대상: 리뷰맵, 돌려받엔, 라익찍스 · 대시보드: Grafana `앱·광고·스토어 현황` (uid `app-ads-overview`)

앱이 외부 서비스(AdMob, Google Ads, Firebase, 스토어)에서 어떤 상태인지를 Prometheus로 가져와 대시보드와 알림 메일로 관리합니다.

## 구조

| 구성요소 | 위치 | 설명 |
|---|---|---|
| 수집기 | 차트 `charts/helm/prod/app-metrics-exporter`, 코드 `files/exporter.py` | 이미지 빌드 없이 `python:3.13-alpine`에 ConfigMap으로 마운트. 표준 라이브러리만 사용 |
| 앱 목록 | `valuefiles/prod/app-metrics-exporter/values.yaml`의 `apps` | 앱 추가·출시 시 이 파일만 고침 |
| 인증 | KSA `monitoring/app-metrics-exporter` → GSA `app-metrics-reader-prod` (Terraform `modules/monitoring`) | Workload Identity. 키 파일 없음 |
| 알림 규칙 | kube-prometheus-stack override의 `app-metrics` | 16종 |
| 대시보드 | `charts/helm/prod/kube-prometheus-stack/dashboards/app-ads-overview-dashboard.json` | 색 기준 = 알림 기준 |

## 수집원

| 수집원 | 주기 | 가져오는 값 | 필요한 권한 |
|---|---|---|---|
| GA4 Data API | 1시간 | 활성·신규 사용자, 세션, 비정상 종료, AdMob 노출·수입, Google Ads 비용·클릭, 이벤트, 앱 버전, 신규 사용자 잔존율(코호트) | GA4 속성 뷰어 (513036605 리뷰맵, 565832639 돌려받엔), yanggo-514212의 `analyticsdata.googleapis.com` |
| Firebase Remote Config | 10분 | 모든 키의 현재 값, 템플릿 버전, 변경 시각 | `reviewmap-c03f1`, `yen-back`, `like-zzix`의 `roles/cloudconfig.viewer`, yanggo-514212의 `firebaseremoteconfig.googleapis.com` |
| AdMob API (v1beta) | 1시간 | 앱 승인 상태, 광고 단위별 요청·매칭·노출·수입 | 사람 계정(woohalabs)의 읽기 토큰. 아래 "AdMob API 연동" |
| App Store 조회 API, Google Play 페이지 | 10분 | 공개 여부, iOS 버전·평점 (Google Play는 버전을 제공하지 않음) | 없음 |
| app-ads.txt | 10분 | 200, Content-Type, 게시자 줄 | 없음 |

- GA4는 하루 단위로 집계되고 값이 최대 48시간 동안 바뀔 수 있어 어제까지의 값만 씁니다.
- AdMob 정책 센터와 지급 정보는 API가 없어 콘솔에서 확인합니다.
- Google Ads 금액은 GA4가 달러로 환산한 값입니다. 청구액 기준은 Google Ads 결제 화면입니다.
- 잔존율(`app_retention_ratio{day="1"|"7", source="ads"|"other"}`)은 8~28일 전 처음 앱을 연 사용자(일별 코호트)가 1일째·7일째 다시 쓴 비율입니다. `source`는 첫 유입이 Google 광고(`google / cpc`, `google / paid`)면 ads, 나머지는 other. 분모는 `app_retention_cohort_users`이며 10명 미만이면 참고만 합니다.
- 수집에 실패하면 이전 값을 유지하고 `app_metrics_collect_ok`가 0이 됩니다.

## 정상 범위와 알림

| 알림 | 정상 | 조건 | 등급 |
|---|---|---|---|
| AppForceUpdateLockout | min_version ≤ 스토어 버전 | 초과 10분 (Android는 실제 사용 중인 최고 버전과 비교) | CRITICAL |
| AppStoreListingMissing | 공개 | `released` 앱이 30분 안 보임 | CRITICAL |
| AppMetricsExporterDown | UP | 10분 수집 불가 | ERROR |
| AppAdsTxtInvalid | 1 | 0이 1시간 | ERROR |
| AdmobApprovalLost | 준비됨 | 하루 전 준비됨이었는데 1시간 벗어남 | ERROR |
| AdmobNotApproved | 준비됨 | 공개 앱이 준비됨이 아닌 채 24시간 | WARN |
| AdmobMatchRateLow | 80% 이상 | 승인 앱 7일 50% 미만, 요청 20회 이상 | WARN |
| AdImpressionsZero | 1회 이상 | 어제 사용자 5명 이상인데 노출 0 | ERROR |
| AppCrashFreeCritical | 95% 이상 (목표 99%) | 7일 85% 미만, 3명 이상 | ERROR |
| AppCrashFreeLow | 95% 이상 (목표 99%) | 7일 95% 미만, 2명 이상 | WARN |
| AdRevenueDropped | 이전 7일의 80% 이상 | 50% 미만, 이전 7일 $0.3 이상 | WARN |
| AppOpenAdShowRateLow | 60% 이상 | 40% 미만, 로드 20회 이상 | WARN |
| AdsSpendWithoutInstalls | 신규 1명당 $1 이하 | 7일 $3 초과인데 광고 유입 0 | WARN |
| AppMetricsCollectStale | GA4 1시간, 그 밖 10분 | GA4 4시간, 그 밖 1시간 초과 | WARN |
| AppRemoteConfigLatestBehind | latest = 스토어 | 하루 넘게 낮음 | INFO |
| AppRemoteConfigChanged | - | 변경 감지 | INFO |

사용자가 적어 비율이 크게 흔들리므로 비율 알림에는 최소 건수 조건이 있습니다.

## AdMob API 연동

AdMob API는 서비스 계정을 쓸 수 없어 사람 계정의 OAuth 토큰이 필요합니다. 토큰이 없으면 AdMob 수집만 건너뜁니다.

| 항목 | 결정 | 이유 |
|---|---|---|
| OAuth 프로젝트 | `yen-back` (2026-11-26 `admob.googleapis.com` 활성화) | 결제가 꺼져 있어 비용이 청구될 수 없음 |
| 토큰 보관 | Kubernetes Secret `monitoring/app-metrics-admob-oauth` | Secret Manager는 활성 버전 무료 한도를 이미 넘어 쓰지 않음. Git에도 두지 않음 |
| 권한 | `admob.readonly` | 읽기만 가능 |
| 게시 상태 | 프로덕션 | 테스트 상태에서는 갱신 토큰이 7일 뒤 만료됨 |

설정 순서 (최초 1회, 2026-11-26 완료)

- [x] `yen-back` 프로젝트의 Google 인증 플랫폼에서 브랜딩 입력, 대상 "외부", 프로덕션으로 게시
- [x] 클라이언트 만들기 → "데스크톱 앱" → JSON을 infra `.secrets/`에 저장 (gitignore 대상)
- [x] `python3 scripts/admob-oauth-setup.py .secrets/<파일>.json` 실행 → woohalabs 계정으로 허용 ("확인되지 않은 앱" 경고는 본인 앱이므로 고급에서 계속)

토큰이 취소되거나 6개월 동안 쓰이지 않으면 만료됩니다. AppMetricsCollectStale(source=admob) 알림이 오면 마지막 단계를 다시 실행합니다.

## 2026-11-26 점검 결과

### AdMob (pub-8516861197467665)

| 항목 | 결과 |
|---|---|
| 정책 센터 | 위반 없음 |
| 리뷰맵 Android·iOS | 준비됨, 매칭률 100% |
| 돌려받엔 iOS | 검토 필요. 스토어·Firebase 연결 완료, 앱 인증은 app-ads.txt 불일치 메시지로 미완료 (재확인해도 같음) |
| 돌려받엔 Android, 라익찍스 2개 | 검토 필요. 스토어 미공개라 연결 불가 |
| 유럽 동의 메시지 | 게시 중. 리뷰맵 2개와 돌려받엔 iOS 포함 |
| 세금 정보 | 미입력 (계정 소유자가 직접 입력) |
| 미디에이션 | 그룹 없음. 리뷰맵 앱에 Unity 어댑터가 들어 있지만 쓰이지 않음 |

최근 7일 수입은 그 전 7일보다 줄었습니다. 활성 사용자 감소와 함께 나타났고, 그 전 주는 11월 중순 강제 업데이트 때 구버전 사용자가 한꺼번에 접속해 높았던 것으로 추정합니다. 실제 수치는 대시보드에서 봅니다(이 저장소는 공개라 사업 수치를 적지 않음).

`woohalabs.com/app-ads.txt`의 Content-Type이 `text/plain,text/plain`으로 중복되던 것을 고쳤습니다(infra #1204). 돌려받엔 인증 실패의 원인인지는 확인되지 않았습니다.

### 리뷰맵 앱에서 찾은 문제

| 문제 | 근거 | 조치 |
|---|---|---|
| 앱 오프닝 광고 표시율이 40% 안팎 | GA4 이벤트 app_open_ad_loaded 대비 app_open_ad_shown | 한 세션에 한 번만 보여주면서 표시 직후 다시 받아 버리던 로드 제거, 시작 화면에서 로드를 잠시 기다림 |
| 비정상 종료 없는 사용자 비율이 정상 범위 밖 | 상위 문제가 모두 실제 종료가 아닌 로딩 실패 | 듣는 쪽이 없는 Future 오류 처리, 종료되지 않은 오류는 fatal로 기록하지 않음 |
| 광고 노출을 원격으로 끌 수 없음 | 광고 관련 Remote Config 키 없음 | 광고 스위치 키 추가 |
| 선택 업데이트 안내가 동작하지 않음 | `updateType`이 recommended를 반환하지 않음 | 판정 로직 수정 |

### Google Ads

최근 28일 동안 사실상 게재되지 않았습니다. 리뷰맵 두 캠페인의 광고 효력은 이미 "좋음"(제목 5, 설명 5, 이미지 9, 동영상 4)이라 소재보다 예산·대상이 원인으로 보입니다. Google 도움말은 예산이 작은 전환수 최대화 캠페인이 전환을 얻지 못할 수 있다고 설명합니다(support.google.com/google-ads/answer/7100895).

| 캠페인 | 변경 전 | 변경 후 (2026-11-26) |
|---|---|---|
| 리뷰맵-안드로이드 | 서울 | 대한민국 (예산은 그대로, 결정 대기) |
| 리뷰맵-iOS | 운영 | 일시중지 |
| 돌려받엔-iOS | 운영 | 일시중지 (1.1.0 출시, AdMob 인증, 설치 전환 연결 뒤 재개) |

예산은 2.2.1 출시 뒤에 정합니다. 전환 100건 전에는 설정을 자주 바꾸지 않는 것이 좋습니다(support.google.com/google-ads/answer/6247380).

## 할 일

- [x] 리뷰맵 2.2.1 코드 머지 (reviewmaps #293), Remote Config v3 배포
- [ ] 리뷰맵 2.2.1 실기기 확인 후 스토어 배포 → Remote Config `{platform}_latest_version`을 2.2.1로 올림
- [ ] 리뷰맵-안드로이드 예산 결정 (개발자)
- [ ] 돌려받엔 iOS AdMob 앱 인증 재확인
- [ ] 돌려받엔 1.1.0 출시 → first_open 전환을 Google Ads로 가져오기 → 캠페인 재개
- [ ] 돌려받엔에 Crashlytics 추가 여부 결정 (개인정보처리방침, App Store 개인정보 신고, 새 빌드 필요). 추가하면 `apps`의 `crashlytics: true`
- [ ] 라익찍스 App Store 심사 통과 → `released`에 추가, AdMob 스토어 연결, GA4 연결, 개인정보 신고 갱신
- [ ] AdMob 세금 정보 입력, Google Ads 보안 제안(관리자 2명, 허용 이메일 도메인) 검토 (계정 소유자)
- [ ] 리뷰맵 2.2.1 배포 1~2주 뒤 앱 오프닝 표시율 60% 이상, 비정상 종료 없는 사용자 95% 이상인지 확인

## 문제 해결

| 증상 | 확인 |
|---|---|
| GA4 403 | GA4 속성 액세스 관리에 GSA가 뷰어로 있는지, `analyticsdata.googleapis.com` 활성화 여부 |
| Remote Config 403 | 앱 Firebase 프로젝트의 `roles/cloudconfig.viewer` (`roles/firebaseremoteconfig.viewer`라는 역할은 없음) |
| insufficient authentication scopes | 메타데이터 토큰 요청에 `scopes=.../analytics.readonly`가 있는지 |
| 값이 안 바뀜 | `app_metrics_collect_ok`, `kubectl -n monitoring logs deploy/app-metrics-exporter` |

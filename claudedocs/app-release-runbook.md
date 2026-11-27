# 앱 출시·광고 연동 절차서 (리뷰맵 · 돌려받엔 · 라익찍스)

작성일: 2026-11-27. 2026-11-26~27 작업에서 실제로 겪은 절차와 문제를 정리했습니다. 비밀번호·키 값은 적지 않습니다(위치는 로컬 `.secrets/README.md`). 이 저장소는 공개라 수입·예산 금액도 적지 않습니다.

## 1. 앱 기본 정보

| 항목 | 리뷰맵 | 돌려받엔 | 라익찍스 |
|---|---|---|---|
| 저장소 | ggorockee/reviewmaps | ggorockee/yen-back | ggorockee/like-zzix |
| App Store ID | 6751343880 | 6835096650 | 6836852971 |
| Android 패키지 | com.reviewmaps.mobile | com.woohalabs.yenback | com.woohalabs.likezzix |
| Firebase 프로젝트 | reviewmap-c03f1 | yen-back | like-zzix |
| GA4 속성 | 513036605 | 565832639 | 없음 (연결 예정) |
| 개발자 웹사이트(app-ads.txt) | review-maps.com | yen-back.woohalabs.com | like-zzix.woohalabs.com |
| Crashlytics | iOS·Android | iOS(1.1.1부터) | 없음 |
| Android 서명 키 | `~/upload-keystore.jks` (리뷰맵·돌려받엔 공용) | 같음 | `~/likezzix-upload-keystore.jks` |

AdMob 게시자: pub-8516861197467665. 계정은 모두 woohalabs@gmail.com.

## 2. iOS 출시 (GitHub Actions)

개발 맥(Intel MacBook Pro 2019)은 macOS 27·Xcode 27을 설치할 수 없습니다. 2027년 4월부터 iOS 27 SDK가 필수라(ITMS-90725) iOS 빌드는 GitHub의 `xcode-27` 러너에서 합니다. 공개 저장소라 무료입니다.

| 단계 | 방법 |
|---|---|
| 1. 버전 올리기 | 앱 저장소 `mobile/pubspec.yaml`의 `version:` 이름 부분(예: 2.2.3)을 올려 PR 머지. 빌드 번호는 워크플로가 정함. **리뷰맵은 `mobile/lib/config/app_version.dart`의 `current`도 함께** 올림 (업데이트 안내가 이 값을 씀, 2.2.3부터 다르면 테스트 실패) |
| 1-1. 업데이트 안내 | `asset/release_notes.json`을 새 버전 내용으로 갱신. 표준·확인 방법 `claudedocs/app-update-card.md` |
| 2. 빌드·업로드 | 저장소 Actions → iOS Release → Run workflow. 빌드 번호를 비우면 실행 시각(UTC, 예: 202611261240). 업로드를 끄면 서명한 ipa만 만들어 확인 |
| 3. 처리 대기 | App Store Connect에서 빌드가 VALID가 될 때까지 10~30분. `python3 scripts/app-status.py` 또는 App Store Connect API로 확인 |
| 4. 버전 만들기 | App Store Connect → 앱 → iOS 앱 옆 + → 버전 번호. "이 버전의 새로운 기능" 입력 (이전 버전 문구가 앞에 붙어 있으면 지움) |
| 5. 빌드 연결 | Build → Add Build → 방금 빌드 선택 → 수출 규정(암호화): 표준 HTTPS만 쓰므로 "None of the algorithms mentioned above" |
| 6. 출시 방식 | "Automatically release this version"(심사 후 자동) 또는 수동. 저장 |
| 7. 제출 | Add for Review → Submit for Review. 심사 최대 48시간 |
| 8. 출시 후 | 수동 출시면 출시 요청(App Store Connect API `appStoreVersionReleaseRequests`로도 가능), Remote Config 최신 버전 올리기(5장) |

워크플로가 쓰는 저장소 시크릿 (값의 위치는 `.secrets/README.md`)

| 시크릿 | 내용 |
|---|---|
| ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64 | App Store Connect API 팀 키 (Admin). 프로비저닝 프로필 자동 관리·업로드 |
| IOS_SIGNING_P12_BASE64, IOS_SIGNING_P12_PASSWORD | Apple Development·Distribution 인증서. 실행 중에만 임시 키체인에 넣고 끝나면 삭제 |
| IOS_BUILD_FILES_BASE64 | git에 없는 빌드 파일 묶음(tar.gz). 리뷰맵 `.env`·`GoogleService-Info.plist`·`ios/Flutter/Release.xcconfig`·`Debug.xcconfig`, 돌려받엔 `GoogleService-Info.plist`, 라익찍스 `env/prod.json`·`Secrets.xcconfig`·`GoogleService-Info.plist`·`firebase_options.dart`. 이 파일을 바꾸면 시크릿도 다시 등록 |

배포 인증서 갱신 (만료 2027-11-26, 약 한 달 전에)

| 단계 | 방법 |
|---|---|
| 1 | 개인 키·CSR 생성: `openssl genrsa` → `openssl req -new` |
| 2 | App Store Connect API `POST /v1/certificates` (certificateType DISTRIBUTION, csrContent)로 발급 |
| 3 | 키+인증서를 p12로 묶어 로그인 키체인에 `security import` |
| 4 | `security export -t identities -f pkcs12`로 키체인의 서명 인증서 전체를 다시 내보냄 (키체인 허용 창에서 로그인 암호 입력) |
| 5 | 세 저장소 `IOS_SIGNING_P12_BASE64` 교체 → 아무 앱이나 iOS Release(업로드 끔)로 서명 확인 |

갱신해도 이미 출시된 앱, 심사 중인 빌드, 푸시·Apple 로그인·AdMob·Firebase에는 영향이 없습니다. 새 빌드 서명에만 쓰입니다.

## 3. Android 출시

| 단계 | 방법 |
|---|---|
| 1. 빌드 | `flutter build appbundle --release --build-name <버전> --build-number <이전보다 큰 수>`. Play에 한 번 올린 번호는 다시 못 씀 |
| 2. 실행 확인 (필수) | 같은 코드로 `flutter build apk --release` → 에뮬레이터에 설치·실행 → `adb logcat -b crash`가 비어 있는지. 릴리스 빌드는 R8이 코드를 지워 디버그에서 안 보이던 종료가 생길 수 있음 |
| 3. 업로드 | Play Console → 프로덕션 → 새 버전 만들기 → AAB를 직접 드래그 (브라우저 자동 업로드는 10MB 제한) |
| 4. 출시 노트 | `<ko-KR>` 태그 안에 입력 |
| 5. 검토 전송 | **관리형 게시가 꺼져 있으면 출시·스토어 등록정보의 "저장"만으로 빠른 검사(최대 14분) 뒤 자동 전송될 수 있음** (2026-11-27 리뷰맵: 저장 후 전송 버튼 없이 "검토 중"이 됨). 전송 시점을 직접 정하려면 저장 전에 관리형 게시를 켬. 승인되면 자동 공개. 자동 검사에서 문제가 나오면 제출이 막힘 → 보고서의 스택 트레이스 확인 |

개인 개발자 계정의 새 앱은 비공개 테스트에서 테스터 12명 이상이 14일 이상 참여해야 프로덕션 액세스를 신청할 수 있습니다(라익찍스는 2026-11-24 시작, 빠르면 12-08).

## 4. 겪은 문제와 해결 (같은 증상이 나오면 여기부터)

| 증상 | 원인 | 해결 |
|---|---|---|
| Play 출시 전 검사: "16KB 페이지 크기를 지원하지 않을 수 있음", `Failed to create an instance of androidx.work.impl.WorkDatabase` | 16KB 문제가 아님. AGP 9의 R8이 Room 데이터베이스 기본 생성자를 지움. Unity Ads SDK 규칙이 가려 주다가 Unity를 빼며 드러남 | `proguard-rules.pro`에 `-keep class * extends androidx.room.RoomDatabase { <init>(); }` (reviewmaps #295, like-zzix #25) |
| Apple 메일 ITMS-90725 (iOS 27 SDK 필요) | 업로드는 성공, 2027-04부터 필수 | GitHub Actions iOS Release로 빌드 (2장) |
| Actions: `Unable to open base configuration reference file .../Release.xcconfig` | 리뷰맵은 xcconfig가 gitignore(네이버 키 포함) | IOS_BUILD_FILES_BASE64에 xcconfig 포함 |
| Actions: `firebase-ios-sdk/Crashlytics/run: No such file or directory` | Swift 패키지가 아직 안 받아진 상태에서 dSYM 업로드 스크립트 실행 | 아카이브 전에 `flutter build ios --config-only` → `xcodebuild -resolvePackageDependencies`. 스크립트는 파일이 없으면 경고만 (reviewmaps #298, #299) |
| Actions 업로드: `Invalid Signature ... GoogleMobileAds.framework is not properly signed` | 서명 없이 아카이브하면 외부 프레임워크가 업로드 단계에서 거부됨 | 인증서 p12를 임시 키체인에 넣고 서명해서 아카이브 (#300 등) |
| 로컬 iOS 아카이브 Crashlytics 스크립트 실패 | 위와 같음 | `xcodebuild -resolvePackageDependencies` 후 다시 빌드 |
| Actions: Flutter 설치 중 `curl: (56)` | 일시적 네트워크 오류 | 다시 실행 |
| AdMob 앱 인증 "app-ads.txt를 확인할 수 없음" (새로 공개한 앱) | 파일이 정상이어도 AdMob이 새 스토어 정보·app-ads.txt를 아직 안 읽음 | 파일 확인(200, text/plain 한 개, 게시자 줄) 후 24시간 안에 "업데이트 확인". AdMob에서 ID로 앱이 안 찾아지면 `https://apps.apple.com/us/app/id<ID>`로 검색 |
| 출시 직후 App Store 검색 API 한국(country=kr) 0건 | 국가별 캐시가 몇 시간~하루 늦음 (미국은 먼저 나옴) | 수집기 `released`는 한국 API에 나온 뒤 변경 (먼저 바꾸면 AppStoreListingMissing 오탐) |
| Google Ads 캠페인이 "운영 가능"인데 노출·비용 0 | 하루 예산이 너무 작으면 앱 캠페인 경매에서 거의 지지 않음 | 예산 확인, 소재(문구·이미지·동영상) 보강 |
| Google Ads 화면에서 캠페인·광고그룹 링크가 안 넘어감 | 브라우저 광고 차단 확장 | ads.google.com에서 끔 |
| 새 버전 빌드가 옛 버전 번호를 표시 (리뷰맵 2.2.3 첫 빌드 `v.2.2.2`) | `pubspec.yaml`만 올리고 앱 안의 버전 상수를 그대로 둠 | `app_version.dart` 수정, pubspec과 비교하는 테스트 추가 (reviewmaps #317). 빌드 뒤 첫 화면의 버전을 눈으로 확인 |
| 다른 도구가 만든 스토어 이미지에 빨간 오류 화면·권한 팝업·iPhone 틀의 Android 이미지·가짜 캠페인 | 캡처 결과를 검수하지 않음 | 올리기 전에 모든 장을 눈으로 확인. 캡처 스크립트는 화면 오류가 있으면 멈춤 (reviewmaps `mobile/tool/`) |
| 스토어 캡처 중 홈 화면 빨간 오류 `_elements.contains(element)` | 캡처 진입점에서 Firebase를 초기화하지 않아 광고 위젯이 예외 (첫 예외는 `[core/no-app]`) | 초기화하되 분석·충돌 수집은 끔. 화면에 보이는 단언문은 두 번째 오류이므로 `FlutterError.onError`의 첫 항목을 볼 것 |
| 캡처한 지도에 영문 지명, 홈에 "8728km" | 시뮬레이터 언어가 영어, 에뮬레이터 위치가 해외 | 캡처 스크립트가 한국어 설정과 위치 고정 |
| Play 스토어 등록정보 저장 시 "AI 애셋 선언" | 2026-11부터 저장 단계에서 선언 필요 | 개발자가 선택 (11-27 리뷰맵: 라벨 지정 안 함) |
| GA4 Admin API 403 | yanggo-514212에서 API가 꺼져 있음 | 켜려면 개발자 승인. 연결 여부는 Google Ads 전환 설정 화면에서 확인 가능 |

## 4-1. 스토어 이미지·문구 갱신

| 단계 | 방법 |
|---|---|
| 1. 문구 원본 | 앱 저장소 `mobile/store/listing.md`를 먼저 고침. 타사·타 앱 이름 금지, 숫자는 실제 값 |
| 2. 이미지 만들기 (리뷰맵) | `listing.md`의 "이미지 만드는 방법" 표. 운영 API 실제 데이터, iOS 시뮬레이터 2종 + Android 에뮬레이터(휴대전화·태블릿 크기), `tool/store_assets.py`로 합성 |
| 3. 검수 | 모든 장을 눈으로 확인 (오류 화면, 팝업, 문구와 화면 일치) |
| 4. App Store 초안 | `uv run --with 'pyjwt[crypto]' python scripts/asc-store.py draft <버전> <listing.md>` → `screenshots <버전> <mobile/store/ios> <슬라이드 목록>` |
| 5. 빌드 연결 | iOS Release 업로드 후 10~30분 → `asc-store.py attach-build <버전>` |
| 6. 제출 준비 | `asc-store.py prepare <버전>` → 심사 목록에 추가까지. 개발자가 App Store Connect에서 "심사에 제출"을 누름 (대신 누를 때만 `submit`). 이름·부제·설명·이미지는 제출해야 공개됨 (홍보 문구만 심사 없이 변경) |
| 7. Play 이미지 | Play Console(개발자 계정은 크롬의 `u/2`) → 사용자 늘리기 → 스토어 등록정보 → 기본 등록정보 수정 → 휴대전화·7인치·10인치·그래픽 이미지 교체 → 저장(AI 애셋 선언은 개발자가 선택, 11-27 "라벨 지정 안 함") → 저장 뒤 자동 전송될 수 있음(3장 5단계) |

캡처 팁: 숙박 요일 화면은 서버의 상세 요일 칸이 비어 있어도 제공 문구로 배지가 보이므로, 앱의 판정 함수(`stayAvailability`)로 공고를 골라야 합니다. Play 스크린샷을 한 번에 여러 장 올리면 업로드가 끝난 순서로 섞이므로 한 장씩 올리거나 끌어서 순서를 맞춥니다.

## 5. Remote Config 최신 버전 올리기

| 단계 | 방법 |
|---|---|
| 1 | 앱이 해당 스토어에 실제 공개됐는지 확인 (`scripts/app-status.py`) |
| 2 | 앱 저장소 `firebase/remoteconfig.template.json`의 `{ios,android}_latest_version`과 업데이트 안내 `release_note` 변경 PR → 머지 |
| 3 | `firebase remoteconfig:get --project <프로젝트>`로 라이브 값과 원본이 같은지 확인 후 `firebase deploy --only remoteconfig --project <프로젝트>` |
| 4 | 최소 버전(`*_min_version`)은 올리지 않으면 선택 업데이트 안내만 나감. 강제 업데이트는 별도 결정 |

## 6. 광고 연동 점검 (앱 검색 → Firebase → AdMob → Google Ads)

| 단계 | 확인 | 연결 방법 |
|---|---|---|
| ① 스토어 | App Store 검색 API(kr·us), Play 공개 페이지 200 | - |
| ② Firebase | `firebase apps:list --project <프로젝트>`에 플랫폼별 앱, Firebase 프로젝트에 Google 애널리틱스(GA4) 사용 | Firebase 콘솔 → 프로젝트 설정 → 통합 → Google 애널리틱스 |
| ③ AdMob | 앱 목록 "스토어 추가"·승인 상태, 설정 → 연결된 서비스 → 앱별 Firebase "연결됨" | 앱 → 스토어 추가 → 앱 인증(app-ads.txt) → 2~3일 검토 |
| ④ Google Ads | 목표 → 전환 → 새 전환 → 앱에서의 전환에 GA4 속성이 보이는지, 전환 액션(설치 / first_open) | 새 전환 → 앱 → 다운로드 → 데이터 소스(GA4 앱) → first_open |

`scripts/app-status.py`가 ①·③(AdMob API)을 자동으로 확인합니다. ②의 GA4 연결과 ④는 콘솔에서 확인합니다. 2026-11-27 점검 결과: 리뷰맵 두 플랫폼과 돌려받엔 iOS는 네 단계 모두 연결, 라익찍스는 GA4가 없어 ②에서 끊김(연결 예정), Android 두 앱(돌려받엔·라익찍스)은 Play 정식 출시 전.

## 7. 광고 운영 원칙

| 원칙 | 이유 |
|---|---|
| 예산은 개발자가 금액을 정한 뒤에만 바꿈 | 실제 청구 |
| 소액이면 노출이 거의 없음 → 증액 후 1주 단위로 노출 → 설치당 비용 → 7일 잔존 순서로 점검 | 2026-11 리뷰맵-안드로이드 사례 |
| 광고비는 "광고 유입 사용자가 남는지" 보는 실험 비용으로 봄 | 사용자 1명당 광고 수입이 작아 광고비로 수익을 직접 키우기 어려움 |
| 잔존율(`app_retention_ratio{source="ads"}`)이 다른 유입보다 낮으면 감액·중지하고 첫 경험부터 개선 | 남지 않는 설치는 수입이 되지 않음 |
| AdMob IDFA 설명 메시지(iOS)는 앱 업데이트 없이 게시 가능 | UMP를 ATT보다 먼저 실행하는 앱(리뷰맵 2.2.0+)에서 UMP가 설명 화면 뒤 ATT를 띄움 |

## 8. 새 앱을 만들 때 처음부터 넣을 것

| 항목 | 기준 앱 |
|---|---|
| 핵심 기능 사용 이벤트 (자체 서버 `/v1/events` 허용 목록 또는 GA4) | 돌려받엔·라익찍스 telemetry |
| Firebase Analytics(GA4), Crashlytics(릴리스 빌드만, silent 오류는 비정상 종료로 세지 않음) | 리뷰맵 `firebase_service.dart`, 돌려받엔 `crash_reporting.dart` |
| Remote Config: 광고 스위치, 최신·최소 버전, 저장소에 `firebase/remoteconfig.template.json` | 리뷰맵 |
| 업데이트 안내 카드 (첫 실행 표시 저장 포함, `claudedocs/app-update-card.md`) | 리뷰맵 |
| UMP 동의 → (iOS) ATT 순서, AdMob IDFA 설명 메시지 | 리뷰맵 |
| app-ads.txt를 개발자 웹사이트 도메인에 (단일 text/plain) | 세 앱 |
| GitHub Actions iOS Release 워크플로·시크릿 | 세 앱 |
| 수집기(app-metrics-exporter) `apps` 항목, 대시보드 범위표 | infra |
| 릴리스 R8 규칙(Room 생성자 보존) | 리뷰맵·라익찍스 |

## 8-1. 리뷰맵 관리자 계정 추가·제거

| 순서 | 할 일 |
|---|---|
| 1 | GSM `prod-reviewmaps-api-credentials`의 `ADMIN_EMAILS`(쉼표 구분)를 고친 새 버전 추가 (실행 직전 개발자 승인) |
| 2 | Google Cloud `yanggo-514212` → Google 인증 플랫폼 → 대상 → 테스트 사용자에 같은 계정 추가 (동의 화면이 테스트 중이라 없으면 Google 로그인 창에서 막힘). 콘솔 저장이 반응하지 않으면 광고 차단 확장을 끄고 다시 |
| 3 | `kubectl -n reviewmaps annotate externalsecret reviewmaps-api-credentials force-sync=$(date +%s) --overwrite` 로 Secret 갱신 (기다리면 1시간 안에 자동) |
| 4 | `kubectl -n reviewmaps rollout restart deploy/reviewmaps-server` (환경변수는 재시작해야 반영) |
| 5 | 확인: 대시보드 `reviewmaps-http-metrics` 관리자 행의 로그인 성공 증가, 허용 목록 밖 시도(INFO 메일)가 없는지 |

예비 로그인(아이디·비밀번호)은 Google 로그인을 쓸 수 없을 때만. 위치는 `.secrets/README.md`.

## 9. 관련 문서

| 문서 | 내용 |
|---|---|
| `.claude/CLAUDE.md` 운영 현황 | 배포 경로, 알림 목록, 앱·광고 운영 메모 |
| `claudedocs/app-metrics-monitoring.md` | 수집기·알림·대시보드 |
| `claudedocs/planning/2026-11-app-ops-plan.md` (로컬 전용) | 단계별 계획, 승인 표시, 진행 기록, 수익 전망, 다음 세션 시작 가이드 |
| `.secrets/README.md` (로컬 전용) | 비밀번호·키·인증서 위치 |
| `scripts/app-status.py` | 상태 점검 (읽기 전용) |

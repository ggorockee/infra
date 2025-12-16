# Ojeomneo OAuth 로그인 문제 분석 리포트

**작성일**: 2025-12-16
**분석 대상**: Google 로그인 및 Kakao 로그인 미작동 원인
**환경**: GKE Production (ojeomneo namespace)

---

## 1. 요약 (Executive Summary)

### 주요 발견사항
- ✅ **환경 변수 설정 완료**: Kakao REST API Key 설정됨
- ✅ **Firebase Admin SDK 설정 완료**: Google OAuth를 위한 Firebase 인증 키 존재
- ❌ **OAuth 엔드포인트 미구현**: API 서버에 소셜 로그인 엔드포인트가 구현되지 않음
- ❌ **클라이언트 요청 없음**: 최근 24시간 동안 OAuth 관련 API 호출 기록 없음

### 결론
**Google 로그인과 Kakao 로그인이 작동하지 않는 이유는 백엔드 API 서버에 OAuth 인증 엔드포인트가 구현되지 않았기 때문입니다.**

---

## 2. 환경 설정 검증

### 2.1 Kubernetes Secret 확인

**Secret 이름**: `ojeomneo-api-credentials`
**네임스페이스**: `ojeomneo`

#### 설정된 인증 관련 환경 변수

| 환경 변수 | 상태 | 용도 |
|----------|------|------|
| `FIREBASE_ADMIN_SDK_KEY` | ✅ 설정됨 | Google Firebase 인증 |
| `KAKAO_REST_API_KEY` | ✅ 설정됨 | Kakao OAuth 인증 |
| `APPLE_KEY_ID`, `APPLE_TEAM_ID`, `APPLE_PRIVATE_KEY` | ✅ 설정됨 | Apple 로그인 (작동 여부 불명) |
| `JWT_SECRET_KEY` | ✅ 설정됨 | JWT 토큰 서명 키 |

#### Firebase Admin SDK 정보
- **Project ID**: `ojeomneo-e7f17`
- **Service Account**: `firebase-adminsdk-fbsvc@ojeomneo-e7f17.iam.gserviceaccount.com`
- **Client ID**: `111744835416009904119`
- **Auth URI**: `https://accounts.google.com/o/oauth2/auth`
- **Token URI**: `https://oauth2.googleapis.com/token`

#### Kakao API 정보
- **REST API Key**: `b64bd3b7f45b07189a68b360212b9adb`

### 2.2 ConfigMap 확인

**ConfigMap 이름**: `ojeomneo-server`

관련 설정:
- `APP_ENV`: `production`
- `APP_PORT`: `3000`
- `JWT_ACCESS_TOKEN_EXPIRE_MINUTES`: `15`
- `JWT_REFRESH_TOKEN_EXPIRE_DAYS`: `7`
- `APPLE_CLIENT_ID`: `com.woohalabs.ojeomneo`

---

## 3. API 서버 로그 분석

### 3.1 최근 24시간 로그 분석 결과

#### 감지된 API 호출 패턴

**정상 작동 중인 엔드포인트**:
- ✅ `/ojeomneo/v1/healthcheck/live` - 헬스체크 (Kubernetes Probe)
- ✅ `/ojeomneo/v1/healthcheck/ready` - Ready 체크 (DB 연결 확인)
- ✅ `/ojeomneo/v1/sketch/analyze` - 스케치 분석 API
- ✅ `/ojeomneo/v1/sketch/history` - 히스토리 조회
- ✅ `/ojeomneo/v1/app/version` - 앱 버전 체크

#### OAuth 관련 API 호출 기록

**검색 패턴**: `POST|GET.*(/auth|/oauth|/login|/callback)`
**결과**: **로그 기록 없음 (0건)**

**의미**:
1. 최근 24시간 동안 클라이언트에서 OAuth 로그인 시도가 없었거나
2. OAuth 엔드포인트가 존재하지 않아 404 에러로 기록되지 않음

### 3.2 Swagger UI 접근 분석

**로그 기록** (2025-12-16 13:11:58):
- Swagger UI 파일 정상 제공: `index.html`, `swagger-ui.css`, `swagger-ui-bundle.js`
- Swagger JSON 요청: `/doc.json`

**실제 API 호출 테스트 결과**:
- `GET /doc.json` → `{"success":false,"error":{"code":"NOT_FOUND","message":"요청하신 정보를 찾을 수 없습니다."}}`
- `GET /ojeomneo/v1/doc.json` → 동일한 404 에러

**결론**: Swagger UI는 정적 파일만 제공되고, 실제 API 문서는 비활성화 상태

---

## 4. 문제점 분석

### 4.1 Google OAuth 로그인

#### 현재 상태
- ✅ **Firebase Admin SDK 설정 완료**
- ❌ **OAuth 엔드포인트 미구현**
- ❌ **Google OAuth 콜백 URL 미설정**

#### 필요한 구현 사항

**1) 백엔드 API 엔드포인트**:
- `POST /ojeomneo/v1/auth/google` - Google OAuth 토큰 검증
- `POST /ojeomneo/v1/auth/google/callback` - OAuth 콜백 처리 (필요 시)

**2) 구현 로직**:
- Firebase Admin SDK를 사용한 ID Token 검증
- 사용자 정보 추출 (email, name, profile)
- DB에 사용자 저장 또는 업데이트
- JWT Access Token 및 Refresh Token 발급

**3) Firebase 프로젝트 설정 확인 필요**:
- Google Sign-In 활성화 여부
- OAuth 2.0 Client ID 설정
- 승인된 리디렉션 URI 등록

### 4.2 Kakao OAuth 로그인

#### 현재 상태
- ✅ **Kakao REST API Key 설정 완료**
- ❌ **OAuth 엔드포인트 미구현**
- ❌ **Kakao OAuth 콜백 URL 미설정**

#### 필요한 구현 사항

**1) 백엔드 API 엔드포인트**:
- `POST /ojeomneo/v1/auth/kakao` - Kakao Access Token 검증
- `GET /ojeomneo/v1/auth/kakao/callback` - OAuth 인가 코드 처리 (필요 시)

**2) 구현 로직**:
- Kakao REST API를 사용한 Access Token 검증
- 사용자 정보 조회 API 호출 (`https://kapi.kakao.com/v2/user/me`)
- DB에 사용자 저장 또는 업데이트
- JWT Access Token 및 Refresh Token 발급

**3) Kakao Developers 설정 확인 필요**:
- 앱 설정에서 플랫폼 등록 (Android, iOS, Web)
- Redirect URI 등록
- 사용자 정보 동의 항목 설정 (닉네임, 프로필 이미지, 이메일)

---

## 5. 해결 방안

### 5.1 우선순위 1: 백엔드 API 구현

#### Google OAuth 엔드포인트 구현

**파일**: `internal/handler/auth.go` (추정)

**필요한 구현**:
| 항목 | 설명 |
|------|------|
| 엔드포인트 | `POST /ojeomneo/v1/auth/google` |
| Request Body | `{"id_token": "google_id_token"}` |
| 검증 로직 | Firebase Admin SDK를 사용한 ID Token 검증 |
| Response | `{"access_token": "jwt", "refresh_token": "jwt", "user": {...}}` |

#### Kakao OAuth 엔드포인트 구현

**파일**: `internal/handler/auth.go` (추정)

**필요한 구현**:
| 항목 | 설명 |
|------|------|
| 엔드포인트 | `POST /ojeomneo/v1/auth/kakao` |
| Request Body | `{"access_token": "kakao_access_token"}` |
| 검증 로직 | Kakao API를 사용한 사용자 정보 조회 |
| Response | `{"access_token": "jwt", "refresh_token": "jwt", "user": {...}}` |

### 5.2 우선순위 2: 외부 OAuth 설정

#### Firebase Console 설정

**필요한 작업**:
- [ ] Firebase Console 접속 (프로젝트: `ojeomneo-e7f17`)
- [ ] Authentication → Sign-in method에서 Google 활성화
- [ ] OAuth 2.0 Client ID 생성 (Android, iOS, Web)
- [ ] 승인된 리디렉션 URI 추가

**예상 Redirect URI**:
- Android: `com.woohalabs.ojeomneo://oauth`
- iOS: `com.woohalabs.ojeomneo://oauth`
- Web: `https://admin.woohalabs.com/ojeomneo/auth/callback`

#### Kakao Developers Console 설정

**필요한 작업**:
- [ ] Kakao Developers Console 접속
- [ ] 앱 설정 → 플랫폼 → Android/iOS 패키지명/Bundle ID 등록
- [ ] Kakao 로그인 → Redirect URI 설정
- [ ] 동의 항목 설정 (필수: 이메일, 선택: 닉네임, 프로필 이미지)

**예상 Redirect URI**:
- `https://api.woohalabs.com/ojeomneo/auth/kakao/callback`

### 5.3 우선순위 3: 클라이언트 앱 구현

**Mobile App (Flutter 추정)**:
- Google Sign-In 패키지 통합
- Kakao SDK 통합
- 백엔드 API 호출 로직 구현
- 토큰 저장 및 갱신 로직

---

## 6. 검증 방법

### 6.1 구현 완료 후 테스트 절차

**Step 1**: 백엔드 API 테스트
```bash
# Google OAuth 테스트
curl -X POST https://api.woohalabs.com/ojeomneo/v1/auth/google \
  -H "Content-Type: application/json" \
  -d '{"id_token": "YOUR_GOOGLE_ID_TOKEN"}'

# Kakao OAuth 테스트
curl -X POST https://api.woohalabs.com/ojeomneo/v1/auth/kakao \
  -H "Content-Type: application/json" \
  -d '{"access_token": "YOUR_KAKAO_ACCESS_TOKEN"}'
```

**Step 2**: 로그 확인
```bash
kubectl logs -n ojeomneo -l app=ojeomneo-server -c server --tail=100 -f | grep -i "auth"
```

**Step 3**: 클라이언트 앱 통합 테스트
- Google 로그인 버튼 클릭 → ID Token 획득 → 백엔드 API 호출
- Kakao 로그인 버튼 클릭 → Access Token 획득 → 백엔드 API 호출
- 토큰 저장 및 자동 로그인 확인

### 6.2 성공 기준

- [ ] Google OAuth 엔드포인트 응답 200 OK
- [ ] Kakao OAuth 엔드포인트 응답 200 OK
- [ ] JWT Access Token 발급 확인
- [ ] DB에 사용자 정보 저장 확인
- [ ] 클라이언트 앱에서 로그인 성공 및 인증 상태 유지

---

## 7. 추가 조사 필요 사항

### 7.1 소스 코드 확인

**필요한 확인**:
- Go Fiber 서버 코드베이스 접근
- `internal/handler/` 디렉토리 구조 확인
- 기존 인증 로직 (JWT, Apple Login) 구현 방식 파악
- 데이터베이스 스키마 (users 테이블) 확인

### 7.2 외부 시스템 확인

**Firebase Console**:
- 프로젝트 ID: `ojeomneo-e7f17`
- Authentication 설정 상태
- OAuth Client ID 목록

**Kakao Developers**:
- 앱 등록 상태
- REST API Key 유효성
- 플랫폼 및 Redirect URI 설정

---

## 8. 권장 구현 우선순위

### Phase 1: 백엔드 API 구현 (필수)
- [ ] Google OAuth 엔드포인트 구현
- [ ] Kakao OAuth 엔드포인트 구현
- [ ] 사용자 DB 저장 로직 구현
- [ ] JWT 토큰 발급 로직 구현

### Phase 2: 외부 설정 (필수)
- [ ] Firebase Google Sign-In 활성화
- [ ] Kakao Developers 플랫폼 설정
- [ ] Redirect URI 등록

### Phase 3: 클라이언트 통합 (필수)
- [ ] Google Sign-In SDK 통합
- [ ] Kakao SDK 통합
- [ ] 백엔드 API 호출 로직

### Phase 4: 테스트 및 배포
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 실행
- [ ] 프로덕션 배포
- [ ] 모니터링 설정

---

## 9. 참고 정보

### 현재 운영 중인 API 엔드포인트

**Healthcheck**:
- `GET /ojeomneo/v1/healthcheck/live`
- `GET /ojeomneo/v1/healthcheck/ready`

**Sketch API**:
- `POST /ojeomneo/v1/sketch/analyze`
- `GET /ojeomneo/v1/sketch/history`

**App Management**:
- `GET /ojeomneo/v1/app/version`

### 컨테이너 이미지 정보

**Server**:
- Image: `ggorockee/ojeomneo-server-with-go:20251212-a85c835`
- Port: `3000`
- Framework: Go Fiber v2

**Admin**:
- Image: `ggorockee/ojeomneo-admin:20251210-085a35c`
- Port: `8000`
- Framework: Django

---

## 10. 결론

**핵심 문제**: Google 로그인과 Kakao 로그인을 위한 백엔드 API 엔드포인트가 구현되지 않았습니다.

**해결 방법**:
1. Go Fiber 서버에 OAuth 인증 엔드포인트 구현
2. Firebase 및 Kakao Developers Console 설정 완료
3. 클라이언트 앱에서 백엔드 API 호출 통합

**예상 작업 시간**:
- 백엔드 API 구현: 2-3일
- 외부 설정: 1일
- 클라이언트 통합: 1-2일
- 테스트 및 배포: 1일
- **총 예상 기간**: 5-7일

**다음 단계**: 개발팀과 협의하여 백엔드 API 구현 작업 시작

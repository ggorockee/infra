# ArgoCD Secret Manager 설정 가이드

ArgoCD 설치를 위해 GCP Secret Manager에 생성해야 할 시크릿 목록과 값 설정 방법입니다.

## 필수 시크릿 목록

### 1. argocd-dex-google-client-id
OAuth 2.0 클라이언트 ID

**값 설정 방법:**
- GCP Console → APIs & Services → Credentials 이동
- Create Credentials → OAuth 2.0 Client ID 선택
- Application type: Web application
- Authorized redirect URIs 추가:
  * `https://argocd.yourdomain.com/api/dex/callback`
  * `https://argocd.yourdomain.com/auth/callback`
- 생성 후 표시되는 Client ID 복사하여 이 시크릿에 저장

**예시 값 형식:**
```
<your-project-number>-<random-string>.apps.googleusercontent.com
```

**gcloud 명령어:**
```bash
gcloud secrets create argocd-dex-google-client-id \
  --data-file=- \
  --replication-policy="automatic" \
  --project=infra-480802
# 실행 후 값 입력하고 Ctrl+D
```

---

### 2. argocd-dex-google-client-secret
OAuth 2.0 클라이언트 시크릿

**값 설정 방법:**
- OAuth 2.0 Client ID 생성 시 함께 표시되는 Client Secret 값 사용

**예시 값 형식:**
```
GOCSPX-<random-alphanumeric-string>
```

**gcloud 명령어:**
```bash
gcloud secrets create argocd-dex-google-client-secret \
  --data-file=- \
  --replication-policy="automatic" \
  --project=infra-480802
# 실행 후 값 입력하고 Ctrl+D
```

---

### 3. argocd-admin-password
ArgoCD 초기 관리자 비밀번호

**값 설정 방법:**
- 원하는 강력한 비밀번호 생성 (최소 8자, 대소문자/숫자/특수문자 포함 권장)
- bcrypt 해시 불필요 (ArgoCD가 자동 처리)

**예시 값:**
```
MySecurePassword123!
```

**gcloud 명령어:**
```bash
gcloud secrets create argocd-admin-password \
  --data-file=- \
  --replication-policy="automatic" \
  --project=infra-480802
# 실행 후 비밀번호 입력하고 Ctrl+D
```

---

### 4. argocd-admin-emails
관리자 권한을 가질 이메일 목록 (JSON 배열)

**값:**
```json
["woohaen88@gmail.com", "woohalabs@gmail.com", "ggorockee@gmail.com"]
```

**gcloud 명령어:**
```bash
echo '["woohaen88@gmail.com", "woohalabs@gmail.com", "ggorockee@gmail.com"]' | \
gcloud secrets create argocd-admin-emails \
  --data-file=- \
  --replication-policy="automatic" \
  --project=infra-480802
```

---

## GCP Console에서 수동 생성 방법

1. GCP Console 접속: https://console.cloud.google.com
2. 프로젝트 선택: `infra-480802`
3. Security → Secret Manager 이동
4. "CREATE SECRET" 버튼 클릭
5. 각 시크릿별로:
   - Name: 위에서 제시한 시크릿 이름 정확히 입력
   - Secret value: 위에서 제시한 값 입력
   - Replication: Automatic 선택
   - "CREATE SECRET" 클릭

---

## 시크릿 생성 확인

모든 시크릿 생성 후 확인:

```bash
gcloud secrets list --project=infra-480802 | grep argocd
```

예상 출력:
```
argocd-admin-emails
argocd-admin-password
argocd-dex-google-client-id
argocd-dex-google-client-secret
```

---

## IAM 권한 설정

Terraform이 이 시크릿들을 읽을 수 있도록 Service Account에 권한 부여 필요:

```bash
# External Secrets 서비스 어카운트에 권한 부여
gcloud secrets add-iam-policy-binding argocd-dex-google-client-id \
  --member="serviceAccount:external-secrets-prod@infra-480802.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=infra-480802

gcloud secrets add-iam-policy-binding argocd-dex-google-client-secret \
  --member="serviceAccount:external-secrets-prod@infra-480802.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=infra-480802

gcloud secrets add-iam-policy-binding argocd-admin-password \
  --member="serviceAccount:external-secrets-prod@infra-480802.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=infra-480802

gcloud secrets add-iam-policy-binding argocd-admin-emails \
  --member="serviceAccount:external-secrets-prod@infra-480802.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project=infra-480802
```

---

## 주의사항

1. **OAuth Client ID 생성 시** Authorized redirect URIs는 실제 ArgoCD 도메인으로 설정 필요
2. **비밀번호는 평문**으로 저장 (ArgoCD가 내부적으로 bcrypt 해시 처리)
3. **관리자 이메일 JSON**은 반드시 배열 형태로 저장 (`["email1", "email2"]`)
4. **시크릿 이름**은 Terraform 코드와 정확히 일치해야 함

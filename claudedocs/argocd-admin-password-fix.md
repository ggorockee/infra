# ArgoCD Admin Password 영구 수정

## 문제 상황

**증상**: ArgoCD admin 로그인 실패 (`Invalid username or password`)

**근본 원인**:
- Helm values의 `configs.secret.argocdServerAdminPassword`에 플레이스홀더 문법 사용
- `$argocd-secrets:admin.password`는 Dex OAuth에서만 작동
- `configs.secret`에서는 bcrypt 해시 직접 필요
- Helm이 재시작할 때마다 플레이스홀더가 그대로 저장됨

## 해결 방법

### 1. Helm이 argocd-secret 생성하지 않도록 설정

**파일**: `gcp/terraform/modules/argocd/values.yaml.tpl`

**변경 전**:
```
configs:
  secret:
    argocdServerAdminPassword: $argocd-secrets:admin.password
```

**변경 후**:
```
configs:
  secret:
    createSecret: false
```

### 2. 별도 Secret 및 초기화 Job 생성

**파일**: `gcp/terraform/modules/argocd/admin-password-secret.tf` (신규)

**구성 요소**:

| 리소스 | 역할 |
|--------|------|
| `kubernetes_secret.argocd_secret` | argocd-secret 베이스 생성 |
| `kubernetes_manifest.argocd_init_password` | 초기화 Job - 비밀번호 bcrypt 해시 생성 |
| `kubernetes_service_account.argocd_init_password` | Job용 ServiceAccount |
| `kubernetes_role.argocd_init_password` | Secret 패치 권한 |
| `kubernetes_role_binding.argocd_init_password` | 권한 바인딩 |

### 3. 동작 방식

**초기화 프로세스**:
1. Terraform이 빈 `argocd-secret` 생성
2. ExternalSecret이 GCP Secret Manager에서 `argocd-secrets` 동기화
3. 초기화 Job 실행:
   - `argocd-secrets`에서 평문 비밀번호 읽기
   - bcrypt 해시 생성 (rounds=10)
   - `argocd-secret`에 해시된 비밀번호 저장
4. ArgoCD가 `argocd-secret`의 해시된 비밀번호 사용

**재시작 시**:
- `argocd-secret`은 Helm이 관리하지 않음 (`createSecret: false`)
- Kubernetes Secret으로 유지되어 재시작 후에도 보존
- 추가 작업 불필요

## 검증 방법

### Terraform Apply 후 확인

**1. Job 실행 확인**:
```
kubectl get job argocd-init-admin-password -n argocd
kubectl logs job/argocd-init-admin-password -n argocd
```

**2. Secret 확인**:
```
kubectl get secret argocd-secret -n argocd -o jsonpath='{.data.admin\.password}' | base64 -d
```
- bcrypt 해시 형식: `$2b$10$...` (60자)

**3. 로그인 테스트**:
- URL: https://argocd.ggorockee.com
- Username: `admin`
- Password: `ggorockee88!1`

### 재시작 후 확인

```
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

로그인이 여전히 정상 작동하는지 확인

## 장점

- ✅ **영구적 해결**: 재시작 시에도 비밀번호 유지
- ✅ **자동화**: Terraform으로 완전 자동화
- ✅ **보안**: bcrypt 해시 사용 (ArgoCD 표준)
- ✅ **중앙 관리**: GCP Secret Manager에서 비밀번호 관리
- ✅ **간단한 변경**: Secret Manager만 업데이트하면 반영 가능

## 비밀번호 변경 방법

**GCP Secret Manager 업데이트**:
```
echo "새로운비밀번호" | gcloud secrets versions add argocd-admin-password --data-file=- --project=infra-480802
```

**초기화 Job 재실행**:
```
kubectl delete job argocd-init-admin-password -n argocd
kubectl apply -f <terraform-generated-job-manifest>
```

또는 Terraform 재실행

## 관련 파일

- `gcp/terraform/modules/argocd/values.yaml.tpl`: Helm values 수정
- `gcp/terraform/modules/argocd/admin-password-secret.tf`: Secret 및 Job 정의 (신규)
- `gcp/terraform/modules/argocd/external-secret.tf`: ExternalSecret 정의 (기존)

## 참고

- ArgoCD 공식 문서: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/
- ExternalSecrets 문서: https://external-secrets.io/latest/

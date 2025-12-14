# GitHub Actions Workflows - GCP Terraform

## 워크플로우 개요

이 디렉토리는 GCP Terraform 인프라를 관리하는 GitHub Actions 워크플로우를 포함합니다.

## 워크플로우 목록

| 워크플로우 | 트리거 | 설명 |
|-----------|--------|------|
| `gcp-terraform-plan.yml` | PR 생성 시 | Terraform Plan 자동 실행 및 결과 PR 코멘트 |
| `gcp-terraform-apply-on-comment.yml` | PR 코멘트 | `apply`, `ok` 코멘트 시 Terraform Apply 실행 |
| `gcp-terraform-apply.yml` | Manual only | 수동 실행 전용 (자동 실행 비활성화) |

## 사용 방법

### 1. PR 생성 및 Plan 확인

**단계**:
1. Feature 브랜치에서 Terraform 코드 수정
2. main 브랜치로 PR 생성
3. `gcp-terraform-plan.yml` 워크플로우 자동 실행
4. PR 코멘트에서 Plan 결과 확인

**Plan 결과 예시**:

```
#### Terraform Format and Style 🖌 `success`
#### Terraform Initialization ⚙️ `success`
#### Terraform Validation 🤖 `success`
#### Terraform Plan 📖 `success`

<details><summary>Show Plan</summary>
...
</details>

---

To apply this plan, comment:
- `apply` or `ok` or `terraform apply`
```

### 2. Apply 승인 및 실행

**방법 1: PR 코멘트 승인**

PR에 다음 중 하나의 코멘트를 입력:
- `apply`
- `ok`
- `terraform apply`

**동작**:
1. `gcp-terraform-apply-on-comment.yml` 워크플로우 자동 트리거
2. 저장된 Plan artifact 다운로드
3. Terraform Apply 실행
4. 결과를 PR 코멘트로 게시

**Apply 성공 예시**:

```
### ✅ Terraform Apply Successful

Applied by: @username

<details><summary>Terraform Outputs</summary>
...
</details>

Environment: Production
Project ID: infra-480802
Timestamp: 2025-12-13T12:00:00Z
```

**방법 2: 수동 실행**

긴급 상황 시 수동으로 실행 가능:
1. GitHub Actions 탭 이동
2. `GCP Terraform Apply (Disabled)` 워크플로우 선택
3. "Run workflow" 클릭
4. 환경 선택 후 실행

### 3. PR 머지

Apply 완료 후:
1. PR 리뷰 및 승인
2. Squash and Merge로 main 브랜치에 병합
3. Feature 브랜치 삭제

**중요**: main 브랜치로 머지해도 자동 Apply는 실행되지 않습니다.

## 보안 및 권한

### GitHub Secrets 필수 설정

| Secret | 설명 | 값 예시 |
|--------|------|---------|
| `GCP_SA_KEY` | Service Account JSON Key | `{...}` |
| `GCP_PROJECT_ID` | GCP 프로젝트 ID | `infra-480802` |

### 워크플로우 권한

모든 워크플로우는 다음 권한을 사용:
- `contents: read` - 코드 읽기
- `pull-requests: write` - PR 코멘트 작성
- `issues: write` - 코멘트 반응 추가

## 워크플로우 상세 설명

### Plan Workflow

**파일**: `gcp-terraform-plan.yml`

**트리거**:
- Pull Request 생성 또는 업데이트
- `gcp/terraform/**` 경로 변경 시

**단계**:
1. Terraform Format Check
2. Terraform Init
3. Terraform Validate
4. Terraform Plan 실행
5. Plan artifact 업로드 (5일 보관)
6. Plan 결과를 PR에 코멘트

**Artifact**:
- 이름: `tfplan-{PR번호}`
- 경로: `gcp/terraform/environments/prod/tfplan`
- 보관 기간: 5일

### Apply Workflow (Comment-based)

**파일**: `gcp-terraform-apply-on-comment.yml`

**트리거**:
- PR 코멘트에 `apply`, `ok`, `terraform apply` 포함 시

**조건**:
- PR 코멘트여야 함 (일반 이슈 코멘트는 무시)
- 키워드가 포함된 경우에만 실행

**단계**:
1. 코멘트에 🚀 리액션 추가
2. PR 정보 가져오기
3. PR 브랜치 체크아웃
4. Terraform Init
5. Plan artifact 다운로드 (있는 경우)
6. Terraform Apply 실행
7. 결과를 PR에 코멘트

**Fallback 동작**:
- Plan artifact가 없으면 새로 Plan 생성 후 Apply

### Apply Workflow (Manual)

**파일**: `gcp-terraform-apply.yml`

**트리거**:
- 수동 실행 전용 (`workflow_dispatch`)

**사용 시나리오**:
- 긴급 배포
- 디버깅
- Plan 없이 직접 Apply 필요 시

## 주의사항

### 1. Plan Artifact 유효 기간

Plan artifact는 5일 후 자동 삭제됩니다.
- Plan 생성 후 5일 이내에 Apply 실행 필요
- 5일 경과 시 새로운 Plan 자동 생성

### 2. 동시 Apply 방지

동일 PR에서 여러 Apply 요청이 들어올 경우:
- GitHub Actions의 concurrency 그룹으로 순차 처리
- 첫 번째 Apply 완료 후 다음 Apply 실행

### 3. State Lock

Terraform State는 GCS 백엔드에서 자동 Lock 관리:
- 동시 Apply 시도 시 Lock으로 보호
- Lock 타임아웃: 기본 설정 사용

### 4. 보안

**민감 정보 관리**:
- Terraform State 파일에 민감 정보 포함 가능
- GCS 버킷 접근 권한 제한
- Service Account Key를 GitHub Secrets에 안전하게 저장

**코멘트 기반 승인**:
- 모든 리포지토리 멤버가 `apply` 코멘트 가능
- 프로덕션 환경의 경우 Branch Protection Rule 설정 권장

## 트러블슈팅

### Plan이 실행되지 않음

**원인**: `gcp/terraform/**` 경로 변경이 없음

**해결**:
- Terraform 코드가 실제로 변경되었는지 확인
- `.github/workflows/gcp-terraform-plan.yml` 파일 변경도 트리거

### Apply가 실행되지 않음

**원인 1**: 코멘트에 키워드가 정확하지 않음

**해결**: `apply`, `ok`, `terraform apply` 중 하나를 정확히 입력

**원인 2**: PR이 아닌 일반 이슈에 코멘트

**해결**: PR에서만 동작하므로 PR 확인

### Plan artifact를 찾을 수 없음

**원인**: Plan 생성 후 5일 경과 또는 Plan 실패

**해결**:
- PR을 다시 업데이트하여 Plan 재생성
- 또는 Apply 워크플로우가 자동으로 새 Plan 생성

## 개선 사항

### 향후 추가 기능

- [ ] Slack/Discord 알림 통합
- [ ] Apply 승인 권한 제한 (CODEOWNERS 활용)
- [ ] 환경별 워크플로우 분리 (dev, staging, prod)
- [ ] Terraform Drift 감지
- [ ] Cost Estimation 통합

### 참고 자료

- GitHub Actions 문서: https://docs.github.com/en/actions
- Terraform GitHub Actions: https://github.com/hashicorp/setup-terraform
- GCP Auth Action: https://github.com/google-github-actions/auth

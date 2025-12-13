# GCP Terraform CI/CD 파이프라인 설계

## 목표

Git 커밋 시 자동으로 Terraform plan 실행, 이상 없으면 apply 자동 실행

## 파이프라인 아키텍처

### 워크플로우

```
1. Feature 브랜치에 코드 푸시
   ↓
2. GitHub Actions: terraform plan 실행
   ↓
3. Plan 결과를 PR 코멘트로 표시
   ↓
4. 코드 리뷰 및 승인
   ↓
5. main 브랜치로 병합 (Squash and Merge)
   ↓
6. GitHub Actions: terraform apply 자동 실행
   ↓
7. 인프라 변경 완료 + 알림
```

## GitHub Actions 구성

### 파일 구조

```
.github/
└── workflows/
    ├── gcp-terraform-plan.yml      # PR 시 plan 실행
    └── gcp-terraform-apply.yml     # main 병합 시 apply 실행
```

### Workflow 1: Terraform Plan (PR 트리거)

**트리거 조건**:
- Pull Request 생성 또는 업데이트
- `gcp/terraform/**` 경로 변경 시

**실행 단계**:
1. 코드 체크아웃
2. GCP 인증 (Service Account Key)
3. Terraform 설치
4. `terraform init`
5. `terraform plan`
6. Plan 결과를 PR 코멘트로 추가

**출력 예시**:
```
Terraform Plan 결과:

Plan: 3 to add, 1 to change, 0 to destroy.

Changes:
+ google_compute_instance.web_server
~ google_compute_firewall.allow_http (security_policy updated)
+ google_sql_database_instance.main
```

### Workflow 2: Terraform Apply (main 병합 트리거)

**트리거 조건**:
- main 브랜치로 PR 병합
- `gcp/terraform/**` 경로 변경 포함

**실행 단계**:
1. 코드 체크아웃
2. GCP 인증
3. Terraform 설치
4. `terraform init`
5. `terraform apply -auto-approve`
6. 결과를 Slack/Discord로 알림

**안전장치**:
- `terraform plan` 먼저 실행하여 변경 사항 확인
- 변경 사항 없으면 apply 스킵
- 실패 시 롤백 알림

## 환경별 워크플로우

### 환경 분리 전략

**옵션 1: 워크플로우 파일 분리**
```
.github/workflows/
├── gcp-terraform-plan-dev.yml
├── gcp-terraform-apply-dev.yml
├── gcp-terraform-plan-prod.yml
└── gcp-terraform-apply-prod.yml
```

**옵션 2: 매트릭스 전략 (권장)**
```yaml
strategy:
  matrix:
    environment: [dev, staging, prod]
```

### 환경별 승인 프로세스

| 환경 | Plan 필수 | 수동 승인 | Auto Apply |
|-----|---------|---------|-----------|
| dev | ✅ | ❌ | ✅ |
| staging | ✅ | ✅ (선택) | ✅ |
| prod | ✅ | ✅ (필수) | ❌ (수동) |

**Production 환경 보호**:
- `environment` 설정으로 수동 승인 필요
- 승인자: DevOps 팀 또는 Tech Lead

## GCP 인증 설정

### Service Account 생성

**Terraform용 Service Account**:
- 이름: `terraform-automation@PROJECT_ID.iam.gserviceaccount.com`
- 역할:
  - Editor (또는 커스텀 Terraform 역할)
  - Storage Admin (Terraform State 백엔드)

### Service Account Key 발급

**발급 명령어**:
```
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account=terraform-automation@PROJECT_ID.iam.gserviceaccount.com
```

**주의**: Key 파일을 Git에 절대 커밋하지 않음

### GitHub Secrets 설정

**필요한 Secrets**:

| Secret 이름 | 값 | 설명 |
|-----------|---|------|
| `GCP_PROJECT_ID` | `infra` | GCP 프로젝트 ID |
| `GCP_SA_KEY` | `{JSON 내용}` | Service Account Key 전체 내용 |
| `TF_STATE_BUCKET` | `woohalabs-terraform-state` | State 백엔드 버킷 |

**설정 위치**: GitHub Repository → Settings → Secrets and variables → Actions

## Terraform Backend 설정

### GCS 백엔드

**backend.tf**:
```
terraform {
  backend "gcs" {
    bucket = "woohalabs-terraform-state"
    prefix = "env/prod"
  }
}
```

**State 잠금 (Locking)**:
- GCS는 기본적으로 State Locking 지원
- 동시 실행 방지

### 환경별 State 분리

```
gs://woohalabs-terraform-state/
├── env/
│   ├── dev/
│   │   └── default.tfstate
│   ├── staging/
│   │   └── default.tfstate
│   └── prod/
│       └── default.tfstate
```

## 안전장치 및 검증

### 1. Terraform Validate

**Plan 전 검증**:
```
terraform fmt -check
terraform validate
```

### 2. tflint (선택)

**Terraform 코드 린트**:
```
tflint --init
tflint
```

### 3. Checkov (보안 스캔, 선택)

**인프라 보안 검증**:
```
checkov -d . --framework terraform
```

### 4. Cost Estimation (Infracost, 선택)

**비용 예측**:
```
infracost breakdown --path .
```

**출력 예시**:
```
Project: gcp/terraform/environments/prod

 Name                                    Monthly Qty  Unit   Monthly Cost

 google_compute_instance.web_server
 ├─ Instance usage (Linux, n1-standard-1)        730  hours       $24.27
 └─ Standard provisioned storage (pd-standard)    10  GB           $0.40

 google_sql_database_instance.main
 └─ Database instance (db-g1-small)              730  hours       $30.00

 OVERALL TOTAL                                                    $54.67
```

## Plan 결과 시각화

### PR 코멘트 자동 생성

**GitHub Actions에서 구현**:
```yaml
- name: Comment PR with Plan
  uses: actions/github-script@v6
  with:
    script: |
      const output = `#### Terraform Plan 📊

      <details><summary>Show Plan</summary>

      \`\`\`terraform
      ${process.env.PLAN_OUTPUT}
      \`\`\`

      </details>`;

      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: output
      });
```

### Slack 알림

**Apply 완료 시 알림**:
```yaml
- name: Slack Notification
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Terraform Apply completed for ${{ matrix.environment }}'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 롤백 전략

### 1. Terraform State 복원

**State 백업 확인**:
```
gsutil ls gs://woohalabs-terraform-state/env/prod/
```

**이전 State로 복원**:
```
gsutil cp gs://woohalabs-terraform-state/env/prod/default.tfstate.backup \
  gs://woohalabs-terraform-state/env/prod/default.tfstate
```

### 2. Git Revert

**잘못된 커밋 되돌리기**:
```
git revert HEAD
git push origin main
```

**자동 Apply 재실행**:
- Revert 커밋이 main에 병합되면 자동으로 이전 상태로 복원

### 3. 수동 복구

**긴급 상황 시**:
1. GitHub Actions 워크플로우 일시 중지
2. 로컬에서 `terraform apply` 수동 실행
3. 상태 확인 후 워크플로우 재활성화

## 브랜치 보호 규칙

### main 브랜치 보호 설정

**GitHub Repository Settings → Branches → Branch protection rules**:

- ✅ Require a pull request before merging
- ✅ Require approvals (1명 이상)
- ✅ Require status checks to pass before merging
  - `terraform-plan` 체크 필수
- ✅ Require branches to be up to date before merging
- ✅ Do not allow bypassing the above settings

**효과**:
- main에 직접 푸시 불가
- Plan 실패 시 병합 불가
- 코드 리뷰 필수

## 단계별 구현 계획

### Phase 1: 기본 CI 구성 (1주차)

- [ ] Terraform 폴더 구조 생성
- [ ] GCS State 백엔드 버킷 생성
- [ ] Service Account 생성 및 Key 발급
- [ ] GitHub Secrets 설정
- [ ] `terraform-plan.yml` 워크플로우 작성

### Phase 2: Plan 자동화 테스트 (2주차)

- [ ] dev 환경에서 Plan 워크플로우 테스트
- [ ] PR 코멘트 기능 구현
- [ ] Plan 실패 시 알림 설정
- [ ] Terraform validate/fmt 추가

### Phase 3: Apply 자동화 (3주차)

- [ ] `terraform-apply.yml` 워크플로우 작성
- [ ] dev 환경에서 Auto Apply 테스트
- [ ] Slack/Discord 알림 연동
- [ ] 롤백 절차 문서화

### Phase 4: Production 적용 (4주차)

- [ ] staging 환경 추가
- [ ] Production 환경 수동 승인 설정
- [ ] 환경별 워크플로우 분리 또는 매트릭스 전략
- [ ] 전체 프로세스 문서화

### Phase 5: 고급 기능 (선택)

- [ ] Infracost 비용 예측 추가
- [ ] Checkov 보안 스캔 추가
- [ ] Terraform 모듈 버전 관리
- [ ] Drift Detection (State vs 실제 인프라)

## 모니터링 및 감사

### 1. Terraform 실행 이력 추적

**GitHub Actions 로그**:
- 모든 plan/apply 실행 기록
- 누가, 언제, 무엇을 변경했는지 추적

### 2. GCP Audit Logs

**Cloud Logging에서 확인**:
- Terraform이 생성/수정/삭제한 리소스
- Service Account 활동 로그

### 3. State 변경 이력

**GCS 버킷 버전 관리**:
```
gsutil versioning set on gs://woohalabs-terraform-state
```

**이전 State 버전 조회**:
```
gsutil ls -a gs://woohalabs-terraform-state/env/prod/
```

## 비용 및 리소스

### GitHub Actions 무료 범위

**Public Repository**:
- 무제한 무료

**Private Repository**:
- 월 2,000분 무료 (Free 플랜)
- 월 3,000분 무료 (Team 플랜)

**예상 사용량**:
- Plan 워크플로우: 2~3분/실행
- Apply 워크플로우: 3~5분/실행
- 월 예상: 50~100분 (일 2~3회 배포 가정)

### 대안: Terraform Cloud

**무료 티어**:
- 5명까지 무료
- State 관리, Remote Execution
- UI로 Plan/Apply 확인

**장점**:
- GitHub Actions보다 Terraform 특화
- Sentinel Policy (유료)
- Cost Estimation 내장

**단점**:
- 5명 초과 시 유료 ($20/user/month)

## 최종 권장 사항

### 추천 구성

1. **GitHub Actions 사용** (무료, 유연함)
2. **GCS State 백엔드** (안정적, 저렴)
3. **환경별 자동화 수준 분리**:
   - dev: 완전 자동 Apply
   - staging: 자동 Apply (선택적 승인)
   - prod: 수동 승인 후 Apply

4. **Slack 알림** (팀 협업)
5. **Infracost 추가** (비용 예측, 선택)

## 체크리스트

- [ ] GCS State 백엔드 버킷 생성 완료
- [ ] Terraform Service Account 생성 완료
- [ ] GitHub Secrets 설정 완료
- [ ] terraform-plan.yml 작성 및 테스트 완료
- [ ] terraform-apply.yml 작성 및 테스트 완료
- [ ] main 브랜치 보호 규칙 설정 완료
- [ ] PR 코멘트 기능 작동 확인
- [ ] Slack/Discord 알림 설정 완료
- [ ] 롤백 절차 문서화 완료
- [ ] 팀원 교육 완료

## 다음 단계

컨펌 필요 사항:
1. GitHub Actions vs Terraform Cloud 선호도는?
2. Production 환경 자동 Apply 허용 여부는?
3. Slack 또는 Discord 알림 필요 여부는?

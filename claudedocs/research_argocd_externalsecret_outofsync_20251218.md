# ArgoCD ExternalSecret OutOfSync 해결 방안 연구

**연구 일자**: 2025-12-18
**연구 주제**: ArgoCD에서 ExternalSecret 리소스가 건강한 상태임에도 "OutOfSync"로 표시되는 문제 해결

## 📋 요약 (Executive Summary)

ArgoCD와 External Secrets Operator를 함께 사용할 때, ExternalSecret 리소스의 `status.refreshTime`, `status.conditions[].lastTransitionTime` 등의 필드가 지속적으로 업데이트되면서 "OutOfSync" 상태로 표시되는 문제가 발생합니다.

**핵심 해결 방안**:
1. ArgoCD ConfigMap에서 `ignoreResourceUpdates` 설정으로 status 필드 변경 무시
2. 전역 또는 Application별 `ignoreDifferences` 설정 적용
3. Custom Health Check 구성으로 정확한 상태 판단

**신뢰도**: 높음 (공식 문서 + 커뮤니티 검증된 사례)

## 🎯 문제 상황

### 발생 원인

| 원인 | 설명 |
|------|------|
| Status 필드 자동 업데이트 | External Secrets Controller가 `status.refreshTime`, `status.conditions` 등을 주기적으로 업데이트 |
| ResourceVersion 변경 | Status 업데이트마다 `metadata.resourceVersion`이 증가하여 ArgoCD가 변경으로 감지 |
| 불필요한 Reconciliation | 실제 spec 변경이 없어도 status 변경으로 인한 지속적인 reconcile 발생 |
| 높은 CPU 사용률 | argocd-application-controller의 과도한 CPU 사용 초래 |

### 영향

- Application 상태가 지속적으로 "OutOfSync"로 표시
- 불필요한 reconciliation으로 인한 성능 저하
- 실제 설정 drift와 status 업데이트를 구분하기 어려움

## ✅ 해결 방안

### 방안 1: ignoreResourceUpdates 설정 (권장)

**적용 범위**: 전역 (모든 ExternalSecret 리소스)

**설정 위치**: `argocd-cm` ConfigMap

**설정 내용**:

| 항목 | 값 |
|------|-----|
| ConfigMap | `argocd-cm` |
| Namespace | `argocd` (또는 ArgoCD 설치 네임스페이스) |
| 설정 키 | `resource.customizations.ignoreResourceUpdates.external-secrets.io_ExternalSecret` |

**적용 예시**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # ExternalSecret의 status.refreshTime 필드 변경 무시
  resource.customizations.ignoreResourceUpdates.external-secrets.io_ExternalSecret: |
    jsonPointers:
      - /status/refreshTime
      - /status/conditions
      - /status/binding
      - /status/syncedResourceVersion
```

**특징**:
- **장점**: 모든 ExternalSecret에 일괄 적용, 관리 포인트 단일화
- **단점**: 전역 설정이므로 특정 Application만 제외 불가
- **동작**: status 필드 변경 시 resource update 이벤트 무시, Application 건강 상태 변경 없으면 reconciliation 발생 안 함

### 방안 2: Application별 ignoreDifferences 설정

**적용 범위**: Application 단위

**설정 위치**: ArgoCD Application 매니페스트

**적용 예시**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets-demo
  namespace: argocd
spec:
  # ... 기타 설정 ...
  ignoreDifferences:
    - group: external-secrets.io
      kind: ExternalSecret
      jsonPointers:
        - /status
      # 또는 jqPathExpressions 사용
      jqPathExpressions:
        - .status.refreshTime
        - .status.conditions
```

**특징**:
- **장점**: Application별 세밀한 제어 가능
- **단점**: 각 Application마다 설정 필요, 관리 포인트 증가
- **사용 사례**: 특정 Application의 ExternalSecret만 선택적으로 무시해야 할 때

### 방안 3: 전역 Resource Override 설정

**적용 범위**: 전역 (모든 ExternalSecret 리소스)

**설정 위치**: `argocd-cm` ConfigMap

**적용 예시**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # CRD status 필드 전체 무시 설정
  resource.compareoptions: |
    ignoreResourceStatusField: all
```

**특징**:
- **장점**: 모든 CRD의 status 필드 일괄 처리
- **단점**: ExternalSecret뿐만 아니라 모든 리소스에 영향
- **주의**: 기본값이 'all'이므로 이미 활성화되어 있을 가능성 높음

### 방안 4: Custom Health Check 구성 (선택적)

**목적**: ExternalSecret의 실제 건강 상태를 정확히 판단

**설정 위치**: `argocd-cm` ConfigMap

**적용 예시**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.health.external-secrets.io_ExternalSecret: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.conditions ~= nil then
        for i, condition in ipairs(obj.status.conditions) do
          if condition.type == "Ready" and condition.status == "False" then
            hs.status = "Degraded"
            hs.message = condition.message
            return hs
          end
          if condition.type == "Ready" and condition.status == "True" then
            # metadata.generation과 status.syncedResourceVersion 비교
            if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.syncedResourceVersion ~= nil then
              for w in string.gmatch(obj.status.syncedResourceVersion, "(%d+)-") do
                if tostring(obj.metadata.generation) ~= w then
                  hs.status = "Progressing"
                  hs.message = "Waiting for ExternalSecret"
                  return hs
                end
                hs.status = "Healthy"
                hs.message = condition.message
                return hs
              end
            end
          end
        end
      end
    end
    hs.status = "Progressing"
    hs.message = "Waiting for ExternalSecret"
    return hs
```

**특징**:
- **장점**: ExternalSecret의 실제 동기화 상태 정확히 판단
- **단점**: Lua 스크립트 작성 및 유지보수 필요
- **사용 사례**: 기본 health check로 충분하지 않을 때

## 📊 프로덕션 권장 설정

### 최소 설정 (Minimal)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.ignoreResourceUpdates.external-secrets.io_ExternalSecret: |
    jsonPointers:
      - /status/refreshTime
```

### 권장 설정 (Recommended)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # ExternalSecret status 필드 전체 무시
  resource.customizations.ignoreResourceUpdates.external-secrets.io_ExternalSecret: |
    jsonPointers:
      - /status

  # 기본 CRD status 필드 무시 확인 (기본값: all)
  resource.compareoptions: |
    ignoreResourceStatusField: all
```

### 완전한 설정 (Comprehensive)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Status 업데이트 무시
  resource.customizations.ignoreResourceUpdates.external-secrets.io_ExternalSecret: |
    jsonPointers:
      - /status

  # Custom Health Check (선택적)
  resource.customizations.health.external-secrets.io_ExternalSecret: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.conditions ~= nil then
        for i, condition in ipairs(obj.status.conditions) do
          if condition.type == "Ready" and condition.status == "False" then
            hs.status = "Degraded"
            hs.message = condition.message
            return hs
          end
          if condition.type == "Ready" and condition.status == "True" then
            hs.status = "Healthy"
            hs.message = condition.message
            return hs
          end
        end
      end
    end
    hs.status = "Progressing"
    hs.message = "Waiting for ExternalSecret"
    return hs

  # 전역 CRD status 무시
  resource.compareoptions: |
    ignoreResourceStatusField: all
```

## 🔧 적용 단계

### 1단계: ConfigMap 백업

**현재 설정 백업**:
- `kubectl get configmap argocd-cm -n argocd -o yaml > argocd-cm-backup.yaml`

### 2단계: ConfigMap 수정

**방법 A: kubectl edit 사용**
- `kubectl edit configmap argocd-cm -n argocd`
- 위의 권장 설정 추가

**방법 B: kubectl patch 사용**
- JSON Patch 또는 Strategic Merge Patch 활용

**방법 C: GitOps 방식 (권장)**
- Git 저장소의 argocd-cm.yaml 수정
- ArgoCD가 자동으로 동기화

### 3단계: ArgoCD 재시작 (필요시)

**ConfigMap 변경 사항 즉시 적용**:
- `kubectl rollout restart deployment argocd-application-controller -n argocd`
- `kubectl rollout restart deployment argocd-server -n argocd`

**참고**: 일부 설정은 자동 reload되지만 확실한 적용을 위해 재시작 권장

### 4단계: 검증

**Application 상태 확인**:
- ArgoCD UI에서 ExternalSecret 포함된 Application 확인
- "OutOfSync" → "Synced"로 변경되었는지 확인

**로그 확인**:
- `kubectl logs -n argocd deployment/argocd-application-controller -f`
- 불필요한 reconciliation 로그 감소 확인

## ⚠️ 주의사항

### IgnoreExtraneous의 오해

| 항목 | 설명 |
|------|------|
| 목적 | Git에서 제거된 리소스를 무시 (삭제하지 않음) |
| 오해 | Status 업데이트를 무시하는 용도로 착각 |
| 올바른 사용 | `argocd.argoproj.io/compare-options: IgnoreExtraneous` 어노테이션은 ExternalSecret status 동기화 문제 해결에 **부적합** |

### 공유 리소스 문제

- ExternalSecret을 여러 Application이 공유하는 경우 1:1 매핑 권장
- 공유 불가피할 경우 하나의 Application에서만 관리

### Prune 설정

- ExternalSecret 자체는 삭제되어도 안전 (민감 정보 미포함)
- 생성된 Secret은 `argocd.argoproj.io/sync-options: Prune=false` 어노테이션으로 보호 권장

## 📚 추가 베스트 프랙티스

### External Secrets Operator와 ArgoCD 통합

| 항목 | 권장 사항 |
|------|-----------|
| 인증 방식 | OIDC 기반 trust authentication 사용 (static token 지양) |
| Secret Store | ClusterSecretStore (전역) vs SecretStore (네임스페이스별) 적절히 선택 |
| Refresh Interval | 프로덕션: 1h, 빈번한 변경: 15s ~ 5m |
| Git 관리 | ExternalSecret manifest는 Git 저장소에 안전하게 저장 (민감 정보 미포함) |
| 네임스페이스 | ArgoCD 리포지토리 credential용 ExternalSecret은 argocd 네임스페이스에 생성 |

### ArgoCD Application 설정

**자동 동기화 예시**:

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Secret 라벨링

**ArgoCD가 인식하도록 라벨 추가**:

```yaml
metadata:
  labels:
    argocd.argoproj.io/secret-type: repository  # 리포지토리 credential용
    # 또는
    argocd.argoproj.io/secret-type: repo-creds  # 리포지토리 credential용 (대체)
```

## 🐛 알려진 이슈

### refreshTime 형식 차이

**문제**: refreshTimer가 "5m" 형식인데 ArgoCD는 "5m0s" 기대
**영향**: OutOfSync 상태 발생
**해결**: `ignoreResourceUpdates`로 `/status/refreshTime` 무시

### OnChange Policy 감지 불가

**문제**: `refreshInterval: OnChange` 사용 시 ArgoCD가 변경 감지 못함
**영향**: Secret 업데이트 여부 판단 불가
**해결**: Custom Health Check로 `metadata.generation`과 `status.syncedResourceVersion` 비교

### Lua Discovery Script 에러

**문제**: ArgoCD UI에서 ExternalSecret 리소스 표시 실패
**영향**: "Lua discovery script failure" 에러
**해결**: ArgoCD 버전 업그레이드 또는 health check Lua 스크립트 수정

## 📈 기대 효과

### 성능 개선

| 항목 | 개선 전 | 개선 후 |
|------|---------|---------|
| Reconciliation 빈도 | ExternalSecret refresh마다 (5분~1시간 주기) | Spec 변경 시에만 |
| CPU 사용률 | 높음 (불필요한 reconcile) | 정상 범위 |
| OutOfSync 표시 | 지속적 | Spec 실제 차이 발생 시에만 |

### 운영 효율성

- 실제 drift와 무해한 status 업데이트 명확히 구분
- ArgoCD UI에서 올바른 동기화 상태 확인
- Alert 피로도 감소 (false positive 제거)

## 🔗 참고 자료

### 공식 문서

- [ArgoCD Diff Customization](https://argo-cd.readthedocs.io/en/stable/user-guide/diffing/)
- [ArgoCD Reconcile Optimization](https://argo-cd.readthedocs.io/en/stable/operator-manual/reconcile/)
- [ArgoCD Secret Management](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)
- [ArgoCD Resource Health](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/)

### 커뮤니티 가이드

- [Securing GitOps with External Secrets Operator & AWS Secrets Manager](https://codefresh.io/blog/aws-external-secret-operator-argocd/)
- [Secrets Management with External Secrets, Argo CD and GitOps](https://colinwilson.uk/2022/08/22/secrets-management-with-external-secrets-argo-cd-and-gitops/)
- [GitOps Secrets with Argo CD, Hashicorp Vault, and External Secret Operator](https://codefresh.io/blog/gitops-secrets-with-argo-cd-hashicorp-vault-and-the-external-secret-operator/)

### GitHub Issues

- [ExternalSecret OutOfSync because refreshTimer format](https://github.com/argoproj/argo-cd/discussions/13487)
- [When annotation is not set, externalsecret resource always sync](https://github.com/argoproj/argo-cd/issues/13825)
- [ExternalSecret health check for OnChange refreshPolicy](https://github.com/argoproj/argo-cd/issues/22707)
- [Ignore CRD status diff by default](https://github.com/argoproj/argo-cd/issues/3393)

### 프로덕션 예시

- [EPAM edp-cluster-add-ons - ExternalSecret for ArgoCD](https://github.com/epam/edp-cluster-add-ons/blob/main/argo-cd/templates/external-secrets/externalsecret-argocd-github.yaml)
- [ocp-gitops-argocd-with-external-secrets](https://github.com/acidonper/ocp-gitops-argocd-with-external-secrets)

## 💡 결론

ArgoCD와 ExternalSecret의 OutOfSync 문제는 **`argocd-cm` ConfigMap에 `ignoreResourceUpdates` 설정을 추가**하여 간단히 해결할 수 있습니다.

**최소 조치**:
```yaml
resource.customizations.ignoreResourceUpdates.external-secrets.io_ExternalSecret: |
  jsonPointers:
    - /status/refreshTime
```

**권장 조치**:
```yaml
resource.customizations.ignoreResourceUpdates.external-secrets.io_ExternalSecret: |
  jsonPointers:
    - /status
```

이 설정은 ArgoCD 공식 문서에 명시되어 있으며, 커뮤니티에서 널리 검증된 프로덕션 레벨 솔루션입니다.

---

**연구 완료**: 2025-12-18
**신뢰도**: 높음 (공식 문서 기반 + 다수의 프로덕션 검증 사례)

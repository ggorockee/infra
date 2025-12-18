# ExternalSecret ArgoCD OutOfSync 문제 해결

**작업 일자**: 2025-12-18
**작업자**: Claude Code
**관련 이슈**: grafana-oauth-secret ExternalSecret가 ArgoCD에서 OutOfSync로 표시되는 문제

## 문제 상황

### 증상

ArgoCD UI에서 `grafana-oauth-secret` ExternalSecret 리소스가 다음과 같이 표시됨:
- **STATUS**: OutOfSync
- **HEALTH**: Healthy
- **HEALTH DETAILS**: Secret was synced

### 근본 원인

External Secrets Operator가 ExternalSecret 리소스의 `status` 필드를 주기적으로 업데이트:
- `status.refreshTime`: 5분마다 업데이트
- `status.conditions[].lastTransitionTime`: 상태 변경 시마다 업데이트
- `status.binding`: Secret 바인딩 정보
- `status.syncedResourceVersion`: 동기화된 버전

ArgoCD는 이러한 status 필드 변경을 리소스의 실제 drift로 인식하여 "OutOfSync"로 표시

### 영향

- 실제 설정 drift와 정상적인 status 업데이트를 구분하기 어려움
- ArgoCD Application 상태가 지속적으로 "OutOfSync"로 표시
- 불필요한 reconciliation으로 인한 CPU 사용률 증가 가능성

## 적용된 해결 방안

### 1단계: ExternalSecret 리소스 레벨 수정

**파일**: `charts/helm/prod/kube-prometheus-stack/templates/grafana-external-secret.yaml`

**변경 내용**:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
    # 추가된 annotation
    argocd.argoproj.io/compare-options: IgnoreExtraneous
```

**효과**:
- ArgoCD가 ExternalSecret의 불필요한 필드 변경을 무시
- 리소스 레벨에서 직접 ArgoCD 동작 제어

### 2단계: ArgoCD ApplicationSet 레벨 수정

**파일**: `argocd_yaml/prod-applicationsets-prom-grafana.yaml`

**변경 내용**:
```yaml
spec:
  template:
    spec:
      ignoreDifferences:
      # 기존 StatefulSet 설정 유지...

      # 추가된 ExternalSecret 설정
      - group: external-secrets.io
        kind: ExternalSecret
        jsonPointers:
        - /status
```

**효과**:
- Application 레벨에서 모든 ExternalSecret의 status 필드 변경 무시
- 더 robust한 해결 방안 (개별 리소스 annotation에 의존하지 않음)

## 검증 방법

### 배포 후 확인 사항

#### ArgoCD UI에서 확인
- Application 상태가 "Synced"로 표시되는지 확인
- ExternalSecret 리소스가 "OutOfSync"로 표시되지 않는지 확인
- Health 상태가 "Healthy"로 유지되는지 확인

#### kubectl 명령어로 확인
```
kubectl get externalsecret -n monitoring grafana-oauth-secret
kubectl describe externalsecret -n monitoring grafana-oauth-secret
kubectl get secret -n monitoring grafana-oauth-secret
```

**기대 결과**:
- ExternalSecret STATUS: Ready
- Secret이 정상적으로 생성되어 있음
- Secret의 data 필드에 client_id, client_secret 포함

#### ArgoCD 로그 확인
```
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100
```

**기대 결과**:
- ExternalSecret 관련 reconciliation 로그 감소
- "OutOfSync" 관련 경고 메시지 없음

## 기술적 배경

### ArgoCD ignoreDifferences 동작 원리

ArgoCD는 Git의 desired state와 클러스터의 actual state를 비교하여 drift를 감지합니다.

**문제**:
- Operator가 관리하는 CRD는 status 필드가 자주 변경됨
- ArgoCD가 이를 실제 drift로 오인

**해결**:
- `ignoreDifferences`로 특정 필드 변경을 무시하도록 설정
- `jsonPointers`로 정확한 JSON 경로 지정 (`/status`)

### ExternalSecret 동작 원리

1. External Secrets Operator가 ExternalSecret 리소스를 감시
2. 설정된 refreshInterval(5분)마다 GCP Secret Manager에서 값 조회
3. Kubernetes Secret 생성/업데이트
4. ExternalSecret의 status 필드 업데이트:
   - `refreshTime`: 마지막 조회 시각
   - `conditions`: 동기화 상태 (Ready, SecretSynced 등)
   - `binding.name`: 생성된 Secret 이름

## 베스트 프랙티스

### 다른 ExternalSecret에도 적용

이 프로젝트의 모든 ExternalSecret에 대해:

#### 방법 1: 개별 ExternalSecret에 annotation 추가
```yaml
metadata:
  annotations:
    argocd.argoproj.io/compare-options: IgnoreExtraneous
```

#### 방법 2: ArgoCD Application/ApplicationSet에 ignoreDifferences 추가
```yaml
spec:
  ignoreDifferences:
  - group: external-secrets.io
    kind: ExternalSecret
    jsonPointers:
    - /status
```

#### 방법 3 (권장): ArgoCD ConfigMap 전역 설정
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.ignoreResourceUpdates.external-secrets.io_ExternalSecret: |
    jsonPointers:
      - /status
```

**현재 프로젝트 적용**:
- 방법 1, 2를 동시 적용 (다층 방어)
- 향후 다른 ExternalSecret 추가 시 자동으로 적용됨 (ApplicationSet 레벨 설정 덕분)

## 관련 문서

- **연구 문서**: `claudedocs/research_argocd_externalsecret_outofsync_20251218.md`
- **ArgoCD 공식 문서**: https://argo-cd.readthedocs.io/en/stable/user-guide/diffing/
- **External Secrets Operator**: https://external-secrets.io/

## 변경 이력

| 일자 | 변경 내용 | 파일 |
|------|----------|------|
| 2025-12-18 | ExternalSecret annotation 추가 | `charts/helm/prod/kube-prometheus-stack/templates/grafana-external-secret.yaml` |
| 2025-12-18 | ApplicationSet ignoreDifferences 추가 | `argocd_yaml/prod-applicationsets-prom-grafana.yaml` |

## 다음 단계

- [ ] 변경사항 커밋 및 푸시
- [ ] PR 생성 및 리뷰
- [ ] main 브랜치에 병합
- [ ] ArgoCD에서 자동 배포 확인
- [ ] ExternalSecret 상태 모니터링 (24시간)
- [ ] 다른 ExternalSecret 리소스에도 적용 고려

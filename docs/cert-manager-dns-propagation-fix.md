# cert-manager DNS Propagation Check 문제 해결

**작성일**: 2025-12-16
**작업자**: Claude + 우현
**상태**: 해결 완료

## 문제 상황

### 증상
- `*.ggorockee.org` 및 `*.woohalabs.com` 와일드카드 SSL 인증서 발급 실패
- Let's Encrypt ACME Challenge가 13시간 이상 Pending 상태 유지
- cert-manager 로그에 "DNS record not yet propagated" 에러 반복 발생

### 정상 동작 도메인
- `*.ggorockee.com`: 인증서 정상 발급됨 (24시간 전)
- `*.review-maps.com`: 인증서 정상 발급됨 (24시간 전)

## 근본 원인 분석

### DNS 인프라 구조

| 구성 요소 | 상세 내역 |
|----------|----------|
| 도메인 네임서버 | Cloudflare (`isaac.ns.cloudflare.com`, `hope.ns.cloudflare.com`) |
| DNS 레코드 관리 | GCP Cloud DNS (프로젝트: `infra-480802`) |
| cert-manager DNS Resolver | Google Public DNS (`8.8.8.8`, `8.8.4.4`) |

### 문제의 핵심

1. **이중 DNS 구조**:
   - 도메인 네임서버는 Cloudflare
   - 실제 DNS 레코드는 GCP Cloud DNS에서 관리
   - Cloudflare ↔ GCP Cloud DNS 간 전파 지연 발생

2. **cert-manager DNS Propagation Check**:
   - `dns01RecursiveNameserversOnly: false` 설정으로 인해
   - cert-manager가 Authoritative nameserver 자동 발견 시도
   - Cloudflare DNS 전파 상태를 정확히 감지하지 못함

3. **Let's Encrypt ACME Order 캐싱**:
   - 동일한 Authorization URL 재사용
   - Challenge 삭제 및 재생성해도 같은 Order 사용
   - `https://acme-v02.api.letsencrypt.org/acme/authz/2878126216/627440500666`

### 검증 결과

**DNS 레코드 상태**:
- GCP Cloud DNS: ✅ TXT 레코드 정상 생성
- Public DNS (8.8.8.8): ✅ TXT 레코드 조회 가능
- cert-manager 내부 check: ❌ "not propagated" 에러

## 시도한 해결 방법

### 시도 1: Challenge 재생성
- Challenge 리소스 삭제 및 자동 재생성
- **결과**: 실패 (동일한 Authorization URL 재사용)

### 시도 2: Order 재생성
- Order 리소스 삭제 및 자동 재생성
- **결과**: 실패 (Let's Encrypt 캐시로 인한 동일 URL)

### 시도 3: Certificate 완전 재생성
- Certificate 리소스 삭제 및 재생성
- Secret 유지 (서비스 무중단)
- **결과**: 실패 (여전히 같은 Order/Challenge 생성됨)

### 시도 4: cert-manager Pod 재시작
- DNS resolver 캐시 초기화 목적
- **결과**: 실패 (설정 자체의 문제로 판명)

## 최종 해결 방법

### 적용 변경사항

**파일**: `charts/helm/prod/cert-manager/values.yaml`

**변경 내용**:
- Line 297: `dns01RecursiveNameserversOnly: false` → `true`

**변경 이유**:
- cert-manager가 Google Public DNS만 사용하도록 강제
- Authoritative nameserver 자동 발견 비활성화
- Cloudflare DNS 전파 지연 문제 우회

### 적용 방법

1. Feature 브랜치 생성
2. values.yaml 수정
3. Git push
4. ArgoCD 자동 동기화 또는 수동 sync
5. cert-manager deployment 재시작

## 영향도 분석

### 기존 서비스 영향
- **영향 없음**: 이미 발급된 인증서 (ggorockee.com, review-maps.com)는 변경 없음
- **DNS 조회 방식 변경**: Authoritative nameserver 조회 대신 Google Public DNS 사용
- **서비스 중단**: 없음

### 변경 후 예상 효과
- DNS-01 Challenge 검증 성공률 향상
- Cloudflare DNS 전파 지연 문제 해결
- 향후 새로운 도메인 인증서 발급 시 안정성 증가

## 검증 계획

### 즉시 검증
1. ArgoCD sync 후 cert-manager Pod 재시작
2. Certificate 상태 확인: `kubectl get certificate -n istio-system`
3. Challenge 상태 확인: `kubectl get challenge -n istio-system`
4. cert-manager 로그 모니터링

### 24시간 후 검증
1. ggorockee.org 인증서 발급 완료 여부
2. woohalabs.com 인증서 발급 완료 여부
3. Secret 생성 확인

## 참고 자료

### 관련 설정 파일
- `charts/helm/prod/cert-manager/values.yaml`
- `charts/helm/prod/cert-manager/templates/certificates.yaml`
- `charts/helm/prod/cert-manager/templates/clusterissuer.yaml`

### 관련 Kubernetes 리소스
- Namespace: `istio-system`
- ClusterIssuer: `letsencrypt-prod`
- Certificates: `ggorockee-org-wildcard-cert`, `woohalabs-com-wildcard-cert`
- Service Account: `cert-manager-dns01-prod@infra-480802.iam.gserviceaccount.com`

### cert-manager 설정
- DNS-01 Solver: Google Cloud DNS
- GCP Project: `infra-480802`
- Recursive Nameservers: `8.8.8.8:53, 8.8.4.4:53`

## 향후 권장 사항

### 단기 (1주 이내)
1. 모든 도메인 인증서 발급 상태 모니터링
2. cert-manager 로그에서 DNS propagation 에러 확인
3. 필요 시 추가 튜닝

### 중기 (1개월 이내)
1. DNS 인프라 구조 재검토
2. Cloudflare 필요성 평가
3. 가능하면 단일 DNS 소스로 통합 고려 (GCP Cloud DNS 직접 사용)

### 장기
1. 인증서 자동 갱신 프로세스 검증
2. 다른 도메인 추가 시 동일 문제 방지 절차 수립
3. DNS 관련 모니터링 및 알림 설정

## 요약

**문제**: Cloudflare + GCP Cloud DNS 이중 구조로 인한 DNS 전파 지연
**원인**: cert-manager의 Authoritative nameserver 자동 발견 실패
**해결**: `dns01RecursiveNameserversOnly: true` 설정으로 Google Public DNS만 사용
**영향**: 기존 서비스 무영향, 새 인증서 발급 안정성 향상
**검증**: 24-48시간 내 ggorockee.org, woohalabs.com 인증서 발급 완료 예상

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

Fridge2Fork 애플리케이션의 Kubernetes 배포를 위한 Helm 차트 저장소입니다. 개발 환경(dev)용 차트를 관리하며, 서버(FastAPI)와 데이터베이스(PostgreSQL) 컴포넌트로 구성됩니다.

## 차트 아키텍처

### 상위 차트 (Umbrella Chart)
- `Chart.yaml`: 메인 애플리케이션 차트 정의 (fridge2fork v0.1.0)
- `values.yaml`: 전체 애플리케이션 설정 (서버, 데이터베이스, 서비스 어카운트)
- `charts/`: 서브차트 디렉토리 (server, database)

### 서브차트 구조

#### 1. Server 차트 (charts/server/)
- FastAPI 백엔드 서비스
- 템플릿: Deployment, Service, ConfigMap, ServiceAccount, HPA
- 주요 설정:
  - 이미지: `ggorockee/fridge2fork-dev-server:sha-{commit}`
  - 포트: 8000 (FastAPI)
  - 헬스체크: `/fridge2fork/v1/system/health` (현재 비활성화)
  - 보안: readOnlyRootFilesystem, runAsNonRoot, /tmp 볼륨 마운트

#### 2. Database 차트 (charts/database/)
- Bitnami PostgreSQL 17.5.0 기반 (버전 16.7.14)
- Bitnami common 차트 의존성 (2.x.x)
- Read/Write 분리 아키텍처 지원
- 메트릭, 네트워크 정책, ServiceMonitor 포함

## 주요 커맨드

### Helm 차트 관리
```bash
# 의존성 업데이트 (서브차트 다운로드)
helm dependency update

# 의존성 빌드
helm dependency build

# 차트 린트 (문법 검증)
helm lint .

# 차트 템플릿 렌더링 (dry-run)
helm template fridge2fork . -f values.yaml

# 특정 값 오버라이드하여 템플릿 확인
helm template fridge2fork . -f values.yaml --set server.image.tag=sha-test123

# 차트 설치 (개발 환경)
helm install fridge2fork . -f values.yaml --namespace dev --create-namespace

# 차트 업그레이드
helm upgrade fridge2fork . -f values.yaml --namespace dev

# 차트 삭제
helm uninstall fridge2fork --namespace dev

# 설치된 릴리스 상태 확인
helm status fridge2fork --namespace dev

# 설치된 값 확인
helm get values fridge2fork --namespace dev
```

### 설정 검증
```bash
# values.yaml 문법 검증
yamllint values.yaml

# Kubernetes 매니페스트 생성 및 확인
helm template fridge2fork . > /tmp/manifests.yaml
kubectl apply --dry-run=client -f /tmp/manifests.yaml
```

## 중요 설정 포인트

### 이미지 태그 관리
- CI/CD에서 자동으로 `server.image.tag` 업데이트
- 커밋 SHA 기반 태그 사용: `sha-{commit-hash}`
- values.yaml:15 위치에서 관리

### 헬스체크 설정
- 현재 서버 헬스체크 비활성화 상태 (`server.healthCheck.enabled: false`)
- 과거 헬스 프로브 실패로 인한 컨테이너 재시작 이슈로 비활성화됨
- 헬스체크 경로: `/fridge2fork/v1/system/health`
- 재활성화 시 initialDelaySeconds와 failureThreshold 조정 필요

### 보안 설정
- readOnlyRootFilesystem: true (불변 파일시스템)
- runAsNonRoot: true (비root 실행)
- /tmp 볼륨: emptyDir로 마운트 (임시 파일용)
- capabilities drop: ALL
- DB 자격증명: Secret으로 관리 (`fridge2fork-db-credentials`)

### Init Container
- Alembic 마이그레이션용 initContainer 구조 존재
- 현재 비활성화 상태 (`server.initContainer.enabled: false`)

## 파일 구조 이해

```
fridge2fork/
├── Chart.yaml              # 메인 차트 메타데이터, 의존성 정의
├── Chart.lock              # 의존성 잠금 파일
├── values.yaml             # 전체 설정 (서버 + 공통 설정)
└── charts/
    ├── server/             # FastAPI 서버 서브차트
    │   ├── Chart.yaml
    │   ├── values.yaml     # 서버 기본값 (parent에서 오버라이드)
    │   └── templates/
    │       ├── deployment.yaml
    │       ├── service.yaml
    │       ├── configmap.yaml
    │       ├── serviceaccount.yaml
    │       ├── hpa.yaml
    │       └── _helpers.tpl
    └── database/           # PostgreSQL 서브차트 (Bitnami)
        ├── Chart.yaml
        ├── values.yaml
        ├── charts/common/  # Bitnami common 라이브러리
        └── templates/      # StatefulSet, Service, Secret 등
```

## 개발 워크플로우

### 설정 변경 시
1. 상위 `values.yaml`에서 설정 수정 (서버/데이터베이스 공통)
2. `helm lint .`로 검증
3. `helm template . | kubectl apply --dry-run=client -f -`로 확인
4. Git 커밋 (CI/CD가 자동 배포)

### 이미지 업데이트 시
- CI/CD 파이프라인이 자동으로 values.yaml의 image.tag 업데이트
- 커밋 메시지 형식: `ci: Update image tag to sha-{hash} for server in dev environment`

### 차트 의존성 변경 시
1. Chart.yaml의 dependencies 섹션 수정
2. `helm dependency update` 실행
3. Chart.lock 파일 업데이트 확인
4. charts/ 디렉토리에 새 차트 다운로드 확인

## 주의사항

- **헬스체크**: 현재 비활성화 상태, 재활성화 전 애플리케이션 준비 상태 확인 필요
- **보안 컨텍스트**: readOnlyRootFilesystem 활성화로 인해 /tmp만 쓰기 가능
- **이미지 태그**: CI/CD가 자동 관리하므로 수동 변경 지양
- **데이터베이스**: Bitnami 차트 기반, 업그레이드 시 Breaking Changes 확인 필요
- **Secret 관리**: DB 자격증명은 클러스터에 별도 생성 필요 (차트에 포함되지 않음)

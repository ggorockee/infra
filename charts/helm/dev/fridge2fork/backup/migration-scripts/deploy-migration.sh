#!/bin/bash

# Migration Job 배포 스크립트
# 새로운 Job이 생성되도록 타임스탬프 기반 이름 생성

set -e

# 설정
NAMESPACE=${1:-default}
CHART_PATH=${2:-./helm}
VALUES_FILE=${3:-./helm/migration-values.yaml}

# 타임스탬프 생성 (YYYYMMDD-HHMMSS 형식)
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
JOB_SUFFIX="migration-${TIMESTAMP}"

echo "========================================"
echo "🚀 Migration Job 배포 시작"
echo "========================================"
echo "📅 타임스탬프: ${TIMESTAMP}"
echo "📦 네임스페이스: ${NAMESPACE}"
echo "📁 차트 경로: ${CHART_PATH}"
echo "⚙️ Values 파일: ${VALUES_FILE}"
echo "🏷️ Job Suffix: ${JOB_SUFFIX}"
echo "========================================"

# 기존 migration job 삭제 (실패해도 계속 진행)
echo "🧹 기존 migration job 정리 중..."
kubectl delete jobs -l app.kubernetes.io/component=migration -n ${NAMESPACE} --ignore-not-found=true || true

# 완료된 job pod 정리
echo "🧹 완료된 Job Pod 정리 중..."
kubectl delete pods -l app.kubernetes.io/component=migration -n ${NAMESPACE} --field-selector=status.phase=Succeeded --ignore-not-found=true || true
kubectl delete pods -l app.kubernetes.io/component=migration -n ${NAMESPACE} --field-selector=status.phase=Failed --ignore-not-found=true || true

# 잠시 대기 (리소스 정리 시간 확보)
echo "⏳ 리소스 정리 대기 중..."
sleep 5

# 데이터베이스 시크릿 확인
echo "🔐 데이터베이스 시크릿 확인 중..."
if ! kubectl get secret fridge2fork-db-credentials -n ${NAMESPACE} >/dev/null 2>&1; then
    echo "❌ 에러: fridge2fork-db-credentials 시크릿이 존재하지 않습니다."
    echo "💡 다음 명령어로 시크릿을 생성하세요:"
    echo ""
    echo "kubectl create secret generic fridge2fork-db-credentials \\"
    echo "  --from-literal=POSTGRES_SERVER=your-db-host \\"
    echo "  --from-literal=POSTGRES_PORT=5432 \\"
    echo "  --from-literal=POSTGRES_USER=fridge2fork \\"
    echo "  --from-literal=POSTGRES_PASSWORD=your-password \\"
    echo "  --from-literal=POSTGRES_DB=fridge2fork \\"
    echo "  -n ${NAMESPACE}"
    echo ""
    exit 1
fi
echo "✅ 데이터베이스 시크릿 확인 완료"

# Helm 배포 실행
echo "🚀 Helm 배포 실행 중..."
helm upgrade --install fridge2fork-migration ${CHART_PATH} \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --values ${VALUES_FILE} \
  --set migration.jobSuffix=${JOB_SUFFIX} \
  --set migration.enabled=true \
  --wait \
  --timeout=30m

echo "✅ Helm 배포 완료"

# Job 상태 확인
echo "🔍 Job 상태 확인 중..."
JOB_NAME="fridge2fork-migration-${JOB_SUFFIX}"
echo "📋 Job 이름: ${JOB_NAME}"

# Job이 생성될 때까지 대기
echo "⏳ Job 생성 대기 중..."
timeout=60
while [ $timeout -gt 0 ]; do
    if kubectl get job ${JOB_NAME} -n ${NAMESPACE} >/dev/null 2>&1; then
        echo "✅ Job 생성 확인됨"
        break
    fi
    echo "⏳ Job 생성 대기 중... (${timeout}초 남음)"
    sleep 2
    timeout=$((timeout - 2))
done

if [ $timeout -le 0 ]; then
    echo "❌ Job 생성 타임아웃"
    exit 1
fi

# Job 상태 출력
echo "📊 Job 정보:"
kubectl get job ${JOB_NAME} -n ${NAMESPACE}

echo ""
echo "📋 Pod 정보:"
kubectl get pods -l job-name=${JOB_NAME} -n ${NAMESPACE}

echo ""
echo "========================================"
echo "🎉 Migration Job 배포 완료!"
echo "========================================"
echo "📋 Job 이름: ${JOB_NAME}"
echo "📦 네임스페이스: ${NAMESPACE}"
echo ""
echo "📊 실시간 로그 확인:"
echo "kubectl logs -f job/${JOB_NAME} -c alembic-migration -n ${NAMESPACE}"
echo "kubectl logs -f job/${JOB_NAME} -c csv-migration -n ${NAMESPACE}"
echo ""
echo "📈 Job 상태 모니터링:"
echo "kubectl get job ${JOB_NAME} -n ${NAMESPACE} -w"
echo ""
echo "🧹 Job 삭제 (필요시):"
echo "kubectl delete job ${JOB_NAME} -n ${NAMESPACE}"
echo "========================================"
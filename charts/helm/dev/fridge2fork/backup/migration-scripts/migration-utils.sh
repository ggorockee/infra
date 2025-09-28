#!/bin/bash

# Migration Job 유틸리티 스크립트
# Job 관리, 로그 확인, 상태 모니터링 등의 기능 제공

set -e

NAMESPACE=${NAMESPACE:-default}

# 함수 정의
show_help() {
    echo "Migration Job 유틸리티 스크립트"
    echo ""
    echo "사용법: $0 <command> [options]"
    echo ""
    echo "명령어:"
    echo "  deploy [namespace]     - 새로운 migration job 배포"
    echo "  status [namespace]     - 현재 migration job 상태 확인"
    echo "  logs [namespace]       - migration job 로그 확인"
    echo "  clean [namespace]      - 완료된 migration job 정리"
    echo "  delete [namespace]     - 모든 migration job 삭제"
    echo "  monitor [namespace]    - migration job 실시간 모니터링"
    echo ""
    echo "환경변수:"
    echo "  NAMESPACE              - Kubernetes 네임스페이스 (기본값: default)"
    echo ""
    echo "예시:"
    echo "  $0 deploy production"
    echo "  $0 logs"
    echo "  NAMESPACE=production $0 status"
}

get_migration_jobs() {
    local ns=${1:-$NAMESPACE}
    kubectl get jobs -l app.kubernetes.io/component=migration -n ${ns} --no-headers 2>/dev/null || true
}

get_latest_migration_job() {
    local ns=${1:-$NAMESPACE}
    get_migration_jobs ${ns} | sort -k5 -r | head -1 | awk '{print $1}'
}

deploy_migration() {
    local ns=${1:-$NAMESPACE}
    echo "🚀 Migration Job 배포 중... (네임스페이스: ${ns})"

    local script_dir=$(dirname "$0")
    if [ -f "${script_dir}/deploy-migration.sh" ]; then
        ${script_dir}/deploy-migration.sh ${ns}
    else
        echo "❌ deploy-migration.sh 스크립트를 찾을 수 없습니다."
        exit 1
    fi
}

show_status() {
    local ns=${1:-$NAMESPACE}
    echo "📊 Migration Job 상태 (네임스페이스: ${ns})"
    echo "========================================"

    local jobs=$(get_migration_jobs ${ns})
    if [ -z "$jobs" ]; then
        echo "❌ 실행 중인 migration job이 없습니다."
        return
    fi

    echo "📋 Jobs:"
    kubectl get jobs -l app.kubernetes.io/component=migration -n ${ns}

    echo ""
    echo "📦 Pods:"
    kubectl get pods -l app.kubernetes.io/component=migration -n ${ns}

    echo ""
    echo "🔍 최신 Job 상세 정보:"
    local latest_job=$(get_latest_migration_job ${ns})
    if [ -n "$latest_job" ]; then
        kubectl describe job ${latest_job} -n ${ns}
    fi
}

show_logs() {
    local ns=${1:-$NAMESPACE}
    local latest_job=$(get_latest_migration_job ${ns})

    if [ -z "$latest_job" ]; then
        echo "❌ 실행 중인 migration job이 없습니다."
        return
    fi

    echo "📋 Migration Job 로그 (Job: ${latest_job})"
    echo "========================================"

    # Alembic 로그
    echo "🔧 Alembic Migration 로그:"
    kubectl logs job/${latest_job} -c alembic-migration -n ${ns} --tail=50 || echo "Alembic 로그를 가져올 수 없습니다."

    echo ""
    echo "📚 CSV Migration 로그:"
    kubectl logs job/${latest_job} -c csv-migration -n ${ns} --tail=50 || echo "CSV 로그를 가져올 수 없습니다."
}

monitor_migration() {
    local ns=${1:-$NAMESPACE}
    local latest_job=$(get_latest_migration_job ${ns})

    if [ -z "$latest_job" ]; then
        echo "❌ 모니터링할 migration job이 없습니다."
        return
    fi

    echo "📈 Migration Job 실시간 모니터링 (Job: ${latest_job})"
    echo "========================================"
    echo "종료하려면 Ctrl+C를 누르세요."
    echo ""

    # Job 상태 모니터링을 백그라운드에서 실행
    (
        while true; do
            clear
            echo "📊 Job 상태 ($(date)):"
            kubectl get job ${latest_job} -n ${ns} 2>/dev/null || break
            echo ""
            echo "📦 Pod 상태:"
            kubectl get pods -l job-name=${latest_job} -n ${ns} 2>/dev/null || break
            sleep 5
        done
    ) &
    local monitor_pid=$!

    # 로그 스트리밍
    kubectl logs -f job/${latest_job} -c csv-migration -n ${ns} 2>/dev/null || true

    # 모니터링 프로세스 종료
    kill $monitor_pid 2>/dev/null || true
}

clean_completed() {
    local ns=${1:-$NAMESPACE}
    echo "🧹 완료된 Migration Job 정리 중... (네임스페이스: ${ns})"

    # 완료된 Job 삭제
    kubectl delete jobs -l app.kubernetes.io/component=migration -n ${ns} --field-selector=status.successful=1 --ignore-not-found=true
    kubectl delete jobs -l app.kubernetes.io/component=migration -n ${ns} --field-selector=status.failed=1 --ignore-not-found=true

    # 완료된 Pod 삭제
    kubectl delete pods -l app.kubernetes.io/component=migration -n ${ns} --field-selector=status.phase=Succeeded --ignore-not-found=true
    kubectl delete pods -l app.kubernetes.io/component=migration -n ${ns} --field-selector=status.phase=Failed --ignore-not-found=true

    echo "✅ 정리 완료"
}

delete_all() {
    local ns=${1:-$NAMESPACE}
    echo "🗑️ 모든 Migration Job 삭제 중... (네임스페이스: ${ns})"

    kubectl delete jobs -l app.kubernetes.io/component=migration -n ${ns} --ignore-not-found=true
    kubectl delete pods -l app.kubernetes.io/component=migration -n ${ns} --ignore-not-found=true

    echo "✅ 삭제 완료"
}

# 메인 로직
case "${1:-help}" in
    deploy)
        deploy_migration $2
        ;;
    status)
        show_status $2
        ;;
    logs)
        show_logs $2
        ;;
    monitor)
        monitor_migration $2
        ;;
    clean)
        clean_completed $2
        ;;
    delete)
        delete_all $2
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ 알 수 없는 명령어: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
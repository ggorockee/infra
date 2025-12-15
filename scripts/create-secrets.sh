#!/bin/bash

# Secret Manager 생성 스크립트
# 빈 시크릿을 생성하고, 값은 나중에 웹 콘솔에서 업데이트

set -e

PROJECT_ID="infra-480802"
REGION="asia-northeast3"

echo "🔐 Secret Manager 생성 시작..."
echo "프로젝트: $PROJECT_ID"
echo "리전: $REGION"
echo ""

# 1. Database Credentials
echo "📦 1/9: prod-ojeomneo-db-credentials 생성 중..."
gcloud secrets create prod-ojeomneo-db-credentials \
  --replication-policy=user-managed \
  --locations=$REGION \
  --project=$PROJECT_ID \
  --labels=env=prod,app=ojeomneo,category=database || echo "이미 존재합니다."

echo "📦 2/9: prod-reviewmaps-db-credentials 생성 중..."
gcloud secrets create prod-reviewmaps-db-credentials \
  --replication-policy=user-managed \
  --locations=$REGION \
  --project=$PROJECT_ID \
  --labels=env=prod,app=reviewmaps,category=database || echo "이미 존재합니다."

# 2. API Credentials
echo "📦 3/9: prod-ojeomneo-api-credentials 생성 중..."
gcloud secrets create prod-ojeomneo-api-credentials \
  --replication-policy=user-managed \
  --locations=$REGION \
  --project=$PROJECT_ID \
  --labels=env=prod,app=ojeomneo,category=api || echo "이미 존재합니다."

echo "📦 4/9: prod-reviewmaps-api-credentials 생성 중..."
gcloud secrets create prod-reviewmaps-api-credentials \
  --replication-policy=user-managed \
  --locations=$REGION \
  --project=$PROJECT_ID \
  --labels=env=prod,app=reviewmaps,category=api || echo "이미 존재합니다."

# 3. Redis Credentials
echo "📦 5/9: prod-ojeomneo-redis-credentials 생성 중..."
gcloud secrets create prod-ojeomneo-redis-credentials \
  --replication-policy=user-managed \
  --locations=$REGION \
  --project=$PROJECT_ID \
  --labels=env=prod,app=ojeomneo,category=redis || echo "이미 존재합니다."

# 4. Admin Credentials
echo "📦 6/9: prod-ojeomneo-admin-credentials 생성 중..."
gcloud secrets create prod-ojeomneo-admin-credentials \
  --replication-policy=user-managed \
  --locations=$REGION \
  --project=$PROJECT_ID \
  --labels=env=prod,app=ojeomneo,category=admin || echo "이미 존재합니다."

# 5. Naver API Credentials
echo "📦 7/9: prod-reviewmaps-naver-api-credentials 생성 중..."
gcloud secrets create prod-reviewmaps-naver-api-credentials \
  --replication-policy=user-managed \
  --locations=$REGION \
  --project=$PROJECT_ID \
  --labels=env=prod,app=reviewmaps,category=naver-api || echo "이미 존재합니다."

# 6. Monitoring Credentials
echo "📦 8/9: prod-monitoring-smtp-credentials 생성 중..."
gcloud secrets create prod-monitoring-smtp-credentials \
  --replication-policy=user-managed \
  --locations=$REGION \
  --project=$PROJECT_ID \
  --labels=env=prod,app=monitoring,category=smtp || echo "이미 존재합니다."

# 7. ArgoCD Credentials
echo "📦 9/9: prod-argocd-dex-credentials 생성 중..."
gcloud secrets create prod-argocd-dex-credentials \
  --replication-policy=user-managed \
  --locations=$REGION \
  --project=$PROJECT_ID \
  --labels=env=prod,app=argocd,category=dex || echo "이미 존재합니다."

echo ""
echo "✅ Secret Manager 생성 완료!"
echo ""
echo "📋 생성된 Secret 목록:"
gcloud secrets list --project=$PROJECT_ID | grep prod-

echo ""
echo "⚠️  다음 단계:"
echo "1. GCP 콘솔에서 각 Secret에 실제 값 추가"
echo "   https://console.cloud.google.com/security/secret-manager?project=$PROJECT_ID"
echo ""
echo "2. backup_secrets/ 디렉토리의 값을 복사하여 각 Secret에 JSON 형식으로 추가"
echo ""
echo "3. IAM 권한 설정 (다음 스크립트 실행):"
echo "   bash scripts/setup-secret-iam.sh"

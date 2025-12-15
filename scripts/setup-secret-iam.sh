#!/bin/bash

# Secret Manager IAM 권한 설정 스크립트
# Terraform SA와 External Secrets SA에 읽기 권한 부여

set -e

PROJECT_ID="infra-480802"
TERRAFORM_SA="terraform-automation@infra-480802.iam.gserviceaccount.com"
EXTERNAL_SECRETS_SA="external-secrets-prod@infra-480802.iam.gserviceaccount.com"

echo "🔐 Secret Manager IAM 권한 설정 시작..."
echo "프로젝트: $PROJECT_ID"
echo ""

# Terraform Service Account에 Secret Accessor 역할 부여
echo "1️⃣  Terraform SA에 Secret Accessor 역할 부여 중..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$TERRAFORM_SA" \
  --role="roles/secretmanager.secretAccessor" \
  --condition=None

echo "✅ Terraform SA 권한 부여 완료"
echo ""

# External Secrets Operator Service Account에 Secret Accessor 역할 부여
echo "2️⃣  External Secrets SA에 Secret Accessor 역할 부여 중..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$EXTERNAL_SECRETS_SA" \
  --role="roles/secretmanager.secretAccessor" \
  --condition=None

echo "✅ External Secrets SA 권한 부여 완료"
echo ""

# 권한 확인
echo "📋 IAM 정책 확인:"
echo ""
echo "Terraform SA 권한:"
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:serviceAccount:$TERRAFORM_SA"

echo ""
echo "External Secrets SA 권한:"
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:serviceAccount:$EXTERNAL_SECRETS_SA"

echo ""
echo "✅ IAM 권한 설정 완료!"

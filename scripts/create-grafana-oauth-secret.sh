#!/bin/bash
# Grafana OAuth Secret 생성 스크립트
# GCP Secret Manager에 OAuth credentials 저장

set -e

PROJECT_ID="infra-480802"
SECRET_NAME="prod-argocd-dex-credentials"

# JSON 시크릿 템플릿 (실제 값으로 교체 필요)
SECRET_JSON='{
  "google.clientId": "YOUR_GOOGLE_CLIENT_ID",
  "google.clientSecret": "YOUR_GOOGLE_CLIENT_SECRET"
}'

echo "======================================"
echo "Grafana OAuth Secret 생성"
echo "======================================"
echo "프로젝트: $PROJECT_ID"
echo "시크릿 이름: $SECRET_NAME"
echo ""

# 1. Secret이 이미 존재하는지 확인
if gcloud secrets describe $SECRET_NAME --project=$PROJECT_ID &> /dev/null; then
  echo "⚠️  시크릿이 이미 존재합니다."
  echo "새 버전을 추가하시겠습니까? (y/n)"
  read -r response
  if [[ "$response" != "y" ]]; then
    echo "취소되었습니다."
    exit 0
  fi

  # 기존 시크릿에 새 버전 추가
  echo "$SECRET_JSON" | gcloud secrets versions add $SECRET_NAME \
    --project=$PROJECT_ID \
    --data-file=-

  echo "✅ 새 버전이 추가되었습니다."
else
  # 새 시크릿 생성
  echo "📝 시크릿 생성 중..."
  gcloud secrets create $SECRET_NAME \
    --project=$PROJECT_ID \
    --replication-policy="automatic"

  echo "🔑 시크릿 값 추가 중..."
  echo "$SECRET_JSON" | gcloud secrets versions add $SECRET_NAME \
    --project=$PROJECT_ID \
    --data-file=-

  echo "✅ 시크릿이 생성되었습니다."
fi

echo ""
echo "======================================"
echo "시크릿 정보 확인"
echo "======================================"
gcloud secrets describe $SECRET_NAME --project=$PROJECT_ID

echo ""
echo "======================================"
echo "⚠️  중요: 실제 값으로 업데이트 필요"
echo "======================================"
echo "1. Google Cloud Console에서 OAuth Client 생성"
echo "   https://console.cloud.google.com/apis/credentials?project=$PROJECT_ID"
echo ""
echo "2. 다음 명령어로 시크릿 업데이트:"
echo ""
echo "cat > secret.json <<EOF"
echo "$SECRET_JSON"
echo "EOF"
echo ""
echo "# 실제 값으로 수정 후:"
echo "gcloud secrets versions add $SECRET_NAME \\"
echo "  --project=$PROJECT_ID \\"
echo "  --data-file=secret.json"
echo ""
echo "# 또는 직접 입력:"
echo "echo '{
  \"google.clientId\": \"실제_CLIENT_ID\",
  \"google.clientSecret\": \"실제_CLIENT_SECRET\"
}' | gcloud secrets versions add $SECRET_NAME --project=$PROJECT_ID --data-file=-"

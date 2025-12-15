# argocd-secret은 Helm이 생성하도록 둠 (createSecret: false 설정 제거 필요)
# 대신 Job만 실행하여 비밀번호 동기화

# Kubernetes Job to sync admin password from argocd-secrets to argocd-secret
# 이 Job은 한 번만 실행되며, argocd-secrets의 비밀번호를 bcrypt 해시로 변환하여
# argocd-secret에 저장합니다
resource "kubernetes_manifest" "argocd_init_password" {
  manifest = {
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = "argocd-init-admin-password"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      ttlSecondsAfterFinished = 3600 # 1시간 후 자동 삭제
      template = {
        spec = {
          serviceAccountName = "argocd-init-password"
          restartPolicy      = "Never"
          containers = [
            {
              name  = "init-password"
              image = "python:3.11-slim"
              command = [
                "sh",
                "-c",
                <<-EOT
                #!/bin/sh
                set -e

                # bcrypt 설치
                pip install bcrypt --quiet

                # argocd-secrets에서 평문 비밀번호 읽기
                PASSWORD=$(cat /mnt/argocd-secrets/admin.password)

                # bcrypt 해시 생성
                HASHED=$(python3 -c "import bcrypt; print(bcrypt.hashpw('$PASSWORD'.encode(), bcrypt.gensalt(rounds=10)).decode())")

                # base64 인코딩
                HASHED_B64=$(echo -n "$HASHED" | base64 -w0)

                # kubectl 설치
                apt-get update && apt-get install -y curl --quiet
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                chmod +x kubectl
                mv kubectl /usr/local/bin/

                # 기존 server.secretkey 확인 (있으면 보존, 없으면 생성)
                EXISTING_KEY=$(kubectl get secret argocd-secret -n argocd -o jsonpath='{.data.server\.secretkey}' 2>/dev/null || echo "")

                if [ -z "$EXISTING_KEY" ]; then
                  echo "server.secretkey not found, generating new one"
                  apt-get install -y openssl --quiet
                  SERVER_KEY=$(openssl rand -base64 32)
                  SERVER_KEY_B64=$(echo -n "$SERVER_KEY" | base64 -w0)
                else
                  echo "Preserving existing server.secretkey"
                  SERVER_KEY_B64="$EXISTING_KEY"
                fi

                # Kubernetes API를 통해 argocd-secret 패치 (merge로 기존 데이터 보존)
                cat <<EOF > /tmp/patch.json
                {
                  "data": {
                    "admin.password": "$HASHED_B64",
                    "admin.passwordMtime": "$(date -u +%Y-%m-%dT%H:%M:%SZ | base64 -w0)",
                    "server.secretkey": "$SERVER_KEY_B64"
                  }
                }
                EOF

                # Secret 패치
                kubectl patch secret argocd-secret -n argocd --type=merge --patch-file=/tmp/patch.json

                echo "Admin password initialized successfully"
                EOT
              ]
              volumeMounts = [
                {
                  name      = "argocd-secrets"
                  mountPath = "/mnt/argocd-secrets"
                  readOnly  = true
                }
              ]
            }
          ]
          volumes = [
            {
              name = "argocd-secrets"
              secret = {
                secretName = "argocd-secrets"
              }
            }
          ]
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_service_account.argocd_init_password
  ]
}

# ServiceAccount for init password job
resource "kubernetes_service_account" "argocd_init_password" {
  metadata {
    name      = "argocd-init-password"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

# Role for init password
resource "kubernetes_role" "argocd_init_password" {
  metadata {
    name      = "argocd-init-password"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "patch", "update"]
  }

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

# RoleBinding for init password
resource "kubernetes_role_binding" "argocd_init_password" {
  metadata {
    name      = "argocd-init-password"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.argocd_init_password.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.argocd_init_password.metadata[0].name
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

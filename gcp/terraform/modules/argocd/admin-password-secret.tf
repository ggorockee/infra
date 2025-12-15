# argocd-secret을 별도로 생성하여 ExternalSecret의 값을 참조
# Helm이 관리하지 않으므로 재시작 시에도 유지됨
resource "kubernetes_secret" "argocd_secret" {
  metadata {
    name      = "argocd-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "argocd-secret"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  # ArgoCD가 생성하는 server.secretkey는 자동 생성되도록 빈 값으로 설정
  data = {
    "server.secretkey" = ""
  }

  # Lifecycle을 설정하여 server.secretkey는 변경하지 않음
  lifecycle {
    ignore_changes = [
      data["server.secretkey"]
    ]
  }

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

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

                # Kubernetes API를 통해 argocd-secret 패치
                cat <<EOF > /tmp/patch.json
                {
                  "data": {
                    "admin.password": "$HASHED_B64",
                    "admin.passwordMtime": "$(date -u +%Y-%m-%dT%H:%M:%SZ | base64 -w0)"
                  }
                }
                EOF

                # kubectl 설치
                apt-get update && apt-get install -y curl --quiet
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                chmod +x kubectl
                mv kubectl /usr/local/bin/

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
    kubernetes_secret.argocd_secret,
    kubernetes_manifest.argocd_secret,
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

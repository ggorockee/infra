# ExternalSecret for ArgoCD secrets from GCP Secret Manager
resource "kubernetes_manifest" "argocd_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "argocd-secrets"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      secretStoreRef = {
        name = "gcpsm-secret-store"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "argocd-secrets"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "dex.google.clientId"
          remoteRef = {
            key = "argocd-dex-google-client-id"
          }
        },
        {
          secretKey = "dex.google.clientSecret"
          remoteRef = {
            key = "argocd-dex-google-client-secret"
          }
        },
        {
          secretKey = "admin.password"
          remoteRef = {
            key = "argocd-admin-password"
          }
        },
        {
          secretKey = "admin.emails"
          remoteRef = {
            key = "argocd-admin-emails"
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

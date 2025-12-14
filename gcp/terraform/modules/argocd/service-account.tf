# Annotate ArgoCD server service account with Workload Identity
resource "kubernetes_service_account" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name

    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.argocd.email
    }
  }

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

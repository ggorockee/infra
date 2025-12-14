# ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace

    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

# ArgoCD Helm release
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "oci://ghcr.io/argoproj/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # Wait for all resources to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      environment = var.environment
      domain      = var.argocd_domain
      project_id  = var.project_id
    })
  ]

  depends_on = [
    kubernetes_manifest.argocd_secret
  ]
}

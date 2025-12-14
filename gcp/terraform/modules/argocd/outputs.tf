output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_service_account_email" {
  description = "GCP service account email for ArgoCD"
  value       = google_service_account.argocd.email
}

output "argocd_release_status" {
  description = "ArgoCD Helm release status"
  value       = helm_release.argocd.status
}

output "argocd_chart_version" {
  description = "ArgoCD Helm chart version deployed"
  value       = helm_release.argocd.version
}

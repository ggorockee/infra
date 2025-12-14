output "namespace" {
  description = "External Secrets Operator namespace"
  value       = kubernetes_namespace.external_secrets.metadata[0].name
}

output "service_account_name" {
  description = "Kubernetes Service Account name"
  value       = kubernetes_service_account.external_secrets.metadata[0].name
}

output "gcp_service_account_email" {
  description = "GCP Service Account email for External Secrets Operator"
  value       = google_service_account.external_secrets.email
}

output "helm_release_name" {
  description = "External Secrets Operator Helm release name"
  value       = helm_release.external_secrets.name
}

output "helm_release_status" {
  description = "External Secrets Operator Helm release status"
  value       = helm_release.external_secrets.status
}

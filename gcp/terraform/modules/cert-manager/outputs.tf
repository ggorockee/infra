output "cert_manager_namespace" {
  description = "cert-manager namespace"
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

output "dns_service_account_email" {
  description = "GCP Service Account email for DNS-01 challenge"
  value       = google_service_account.cert_manager_dns.email
}

output "cert_manager_service_account" {
  description = "Kubernetes Service Account name for cert-manager"
  value       = kubernetes_service_account.cert_manager.metadata[0].name
}

# Cloud Armor Security Policy Outputs

output "security_policy_id" {
  description = "The ID of the security policy"
  value       = google_compute_security_policy.gke_istio_policy.id
}

output "security_policy_name" {
  description = "The name of the security policy"
  value       = google_compute_security_policy.gke_istio_policy.name
}

output "security_policy_self_link" {
  description = "The self link of the security policy"
  value       = google_compute_security_policy.gke_istio_policy.self_link
}

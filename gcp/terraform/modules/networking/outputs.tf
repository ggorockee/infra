output "network_id" {
  description = "VPC network ID"
  value       = google_compute_network.main.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = google_compute_subnetwork.private.id
}

output "private_subnet_name" {
  description = "Private subnet name"
  value       = google_compute_subnetwork.private.name
}

output "pods_ip_range_name" {
  description = "Pods IP range name for GKE"
  value       = "pods"
}

output "services_ip_range_name" {
  description = "Services IP range name for GKE"
  value       = "services"
}

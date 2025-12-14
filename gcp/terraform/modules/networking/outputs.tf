output "network_id" {
  description = "VPC network ID"
  value       = data.google_compute_network.default.id
}

output "network_name" {
  description = "VPC network name"
  value       = data.google_compute_network.default.name
}

output "private_subnet_id" {
  description = "Default subnet ID"
  value       = data.google_compute_subnetwork.default.id
}

output "private_subnet_name" {
  description = "Default subnet name"
  value       = data.google_compute_subnetwork.default.name
}

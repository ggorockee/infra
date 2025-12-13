output "network_name" {
  description = "VPC 네트워크 이름"
  value       = module.networking.network_name
}

output "gke_cluster_name" {
  description = "GKE 클러스터 이름"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE 클러스터 엔드포인트"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "cloud_sql_instance_name" {
  description = "Cloud SQL 인스턴스 이름"
  value       = module.cloud_sql.instance_name
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL 연결 이름"
  value       = module.cloud_sql.connection_name
}

output "load_balancer_ip" {
  description = "Load Balancer IP 주소"
  value       = module.load_balancer.lb_ip_address
}

output "dns_name_servers" {
  description = "Cloud DNS Name Servers"
  value       = module.dns.name_servers
}

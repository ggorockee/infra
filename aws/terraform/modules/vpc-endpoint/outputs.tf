output "ssm_vpc_endpoint_ids" {
  description = "생성된 SSM VPC 엔드포인트의 ID 목록"
  value       = [for ep in aws_vpc_endpoint.ssm : ep.id]
}

output "ssm_vpc_endpoint_dns_names" {
  description = "각 SSM VPC 엔드포인트의 DNS 이름 목록"
  value       = [for ep in aws_vpc_endpoint.ssm : ep.dns_entry[0].dns_name]
}

output "ssm_vpc_endpoint_network_interface_ids" {
  description = "각 SSM VPC 엔드포인트에 연결된 네트워크 인터페이스(ENI) ID 목록"
  value       = [for ep in aws_vpc_endpoint.ssm : ep.network_interface_ids]
}

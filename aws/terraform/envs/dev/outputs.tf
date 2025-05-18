output "vpc_id" {
  description = "생성된 VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = module.vpc.public_subnet_ids
}


output "private_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = module.vpc.private_subnet_ids
}


output "ssm_vpc_endpoint_ids" {
  description = "생성된 SSM VPC 엔드포인트의 ID 목록"
  value       = module.vpc-endpoint.ssm_vpc_endpoint_ids
}

output "ssm_vpc_endpoint_dns_names" {
  description = "각 SSM VPC 엔드포인트의 DNS 이름 목록"
  value       = module.vpc-endpoint.ssm_vpc_endpoint_dns_names
}

output "ssm_vpc_endpoint_network_interface_ids" {
  description = "각 SSM VPC 엔드포인트에 연결된 네트워크 인터페이스(ENI) ID 목록"
  value       = module.vpc-endpoint.ssm_vpc_endpoint_network_interface_ids
}

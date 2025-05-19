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

## EKS
output "eks_access_entries" {
  description = "Map of access entries created and their attributes"
  value       = module.eks.access_entries
}



output "eks_access_policy_associations" {
  description = "Map of eks cluster access policy associations created and their attributes"
  value       = module.eks.access_policy_associations
}




output "eks_cloudwatch_log_group_arn" {
  description = "Arn of cloudwatch log group created"
  value       = module.eks.cloudwatch_log_group_arn
}



# Description: Name of cloudwatch log group created
# cluster_addons

# Description: Map of attribute maps for all EKS cluster addons enabled
# cluster_arn

# Description: The Amazon Resource Name (ARN) of the cluster
# cluster_certificate_authority_data

# Description: Base64 encoded certificate data required to communicate with the cluster
# cluster_dualstack_oidc_issuer_url

# Description: Dual-stack compatible URL on the EKS cluster for the OpenID Connect identity provider
# cluster_endpoint

# Description: Endpoint for your Kubernetes API server
# cluster_iam_role_arn

# Description: Cluster IAM role ARN
# cluster_iam_role_name

# Description: Cluster IAM role name
# cluster_iam_role_unique_id

# Description: Stable and unique string identifying the IAM role
# cluster_id

# Description: The ID of the EKS cluster. Note: currently a value is returned only for local EKS clusters created on Outposts
# cluster_identity_providers

# Description: Map of attribute maps for all EKS identity providers enabled
# cluster_ip_family

# Description: The IP family used by the cluster (e.g. `ipv4` or `ipv6`)
# cluster_name

# Description: The name of the EKS cluster
# cluster_oidc_issuer_url

# Description: The URL on the EKS cluster for the OpenID Connect identity provider
# cluster_platform_version

# Description: Platform version for the cluster
# cluster_primary_security_group_id

# Description: Cluster security group that was created by Amazon EKS for the cluster. Managed node groups use this security group for control-plane-to-data-plane communication. Referred to as 'Cluster security group' in the EKS console
# cluster_security_group_arn

# Description: Amazon Resource Name (ARN) of the cluster security group
# cluster_security_group_id

# Description: ID of the cluster security group
# cluster_service_cidr

# Description: The CIDR block where Kubernetes pod and service IP addresses are assigned from
# cluster_status

# Description: Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`
# cluster_tls_certificate_sha1_fingerprint

# Description: The SHA1 fingerprint of the public key of the cluster's certificate
# cluster_version

# Description: The Kubernetes version for the cluster
# eks_managed_node_groups

# Description: Map of attribute maps for all EKS managed node groups created
# eks_managed_node_groups_autoscaling_group_names

# Description: List of the autoscaling group names created by EKS managed node groups
# fargate_profiles

# Description: Map of attribute maps for all EKS Fargate Profiles created
# kms_key_arn

# Description: The Amazon Resource Name (ARN) of the key
# kms_key_id

# Description: The globally unique identifier for the key
# kms_key_policy

# Description: The IAM resource policy set on the key
# node_iam_role_arn

# Description: EKS Auto node IAM role ARN
# node_iam_role_name

# Description: EKS Auto node IAM role name
# node_iam_role_unique_id

# Description: Stable and unique string identifying the IAM role
# node_security_group_arn

# Description: Amazon Resource Name (ARN) of the node shared security group
# node_security_group_id

# Description: ID of the node shared security group
# oidc_provider

# Description: The OpenID Connect identity provider (issuer URL without leading `https://`)
# oidc_provider_arn

# Description: The ARN of the OIDC Provider if `enable_irsa = true`
# self_managed_node_groups

# Description: Map of attribute maps for all self managed node groups created
# self_managed_node_groups_autoscaling_group_names

# Description: List of the autoscaling group names created by self-managed node groups

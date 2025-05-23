module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "20.36.0"
  cluster_name = var.cluster_name

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  tags = local.tags

  eks_managed_node_groups = length(var.eks_managed_node_groups) > 0 ? var.eks_managed_node_groups : {}

}


// 프라이빗 서브넷 태그
resource "aws_ec2_tag" "private_subnet_tag" {
  for_each    = toset(var.subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_subnet_cluster_tag" {
  for_each    = toset(var.subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "owned"
}

# resource "aws_ec2_tag" "private_subnet_karpenter_tag" {
#   for_each    = toset(local.private_subnets)
#   resource_id = each.value
#   key         = "karpenter.sh/discovery/${local.cluster_name}"
#   value       = local.cluster_name
# }

# // 퍼블릭 서브넷 태그
# resource "aws_ec2_tag" "public_subnet_tag" {
#   for_each    = toset(local.public_subnets)
#   resource_id = each.value
#   key         = "kubernetes.io/role/elb"
#   value       = "1"
# }


# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "20.36.0"

#   cluster_name    = var.cluster_name
#   cluster_version = var.cluster_version

#   # VPC/서브넷
#   vpc_id     = var.vpc_id
#   subnet_ids = var.private_subnet_ids

#   # 접근제어: aws-auth ConfigMap 비활성화 + AssumeRole
#   authentication_mode = var.authentication_mode
#   access_entries      = local.access_entries


#   # Endpoint 접근 제어
#   cluster_endpoint_private_access = local.cluster_endpoint_private_access
#   cluster_endpoint_public_access  = local.cluster_endpoint_public_access

#   # IRSA/OIDC
#   enable_irsa = local.enable_irsa

#   # CloudWatch Logs
#   create_cloudwatch_log_group = local.create_cloudwatch_log_group

#   # Self-managed Node Groups
#   self_managed_node_groups = var.self_managed_node_groups

#   # KMS
#   create_kms_key            = var.create_kms_key
#   cluster_encryption_config = var.cluster_encryption_config

#   cluster_addons = local.cluster_addons
# }


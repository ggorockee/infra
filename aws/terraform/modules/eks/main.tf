module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # VPC/서브넷
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # 접근제어: aws-auth ConfigMap 비활성화 + AssumeRole
  authentication_mode = var.authentication_mode
  access_entries      = local.access_entries


  # Endpoint 접근 제어
  cluster_endpoint_private_access = local.cluster_endpoint_private_access
  cluster_endpoint_public_access  = local.cluster_endpoint_public_access

  # IRSA/OIDC
  enable_irsa = local.enable_irsa

  # CloudWatch Logs
  create_cloudwatch_log_group = local.create_cloudwatch_log_group

  # Self-managed Node Groups
  self_managed_node_groups = var.self_managed_node_groups

  # KMS
  create_kms_key            = var.create_kms_key
  cluster_encryption_config = var.cluster_encryption_config

  cluster_addons = local.cluster_addons
}


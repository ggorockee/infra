module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name                    = local.cluster_name
  cluster_version                 = local.cluster_version
  cluster_endpoint_public_access  = local.cluster_endpoint_public_access
  cluster_endpoint_private_access = local.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = local.cluster_endpoint_public_access_cidrs

  authentication_mode = local.authentication_mode

  # 관리자(entry)만 미리 정의
  access_entries = local.access_entries

  # EKS Addons
  cluster_addons = local.cluster_addons

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  create_kms_key              = local.create_kms_key
  cluster_encryption_config   = local.cluster_encryption_config
  create_cloudwatch_log_group = local.create_cloudwatch_log_group

  tags = local.tags
}


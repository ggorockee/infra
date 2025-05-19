module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name                   = var.eks_cluster_name
  cluster_version                = var.eks_version
  vpc_id                         = var.vpc_id
  subnet_ids                     = var.private_subnet_ids
  cluster_endpoint_public_access = var.cluster_endpoint_public_access

  cluster_addons = local.merged_addons

  enable_irsa = var.enable_irsa

  authentication_mode = var.authentication_mode

  access_entries = local.access_entries

  cluster_enabled_log_types   = var.cluster_enabled_log_types
  cluster_encryption_config   = var.cluster_encryption_config
  create_cloudwatch_log_group = var.create_cloudwatch_log_group


  cluster_security_group_additional_rules = length(var.cluster_security_group_additional_rules) > 0 ? var.cluster_security_group_additional_rules : {}

  node_security_group_additional_rules = length(var.node_security_group_additional_rules) > 0 ? var.node_security_group_additional_rules : {}

  eks_managed_node_groups = {
    for ng_name, config in var.eks_managed_node_groups : ng_name => {
      name             = config.name
      desired_capacity = config.desired_capacity
      max_capacity     = config.max_capacity
      min_capacity     = config.min_capacity
      instance_type    = config.instance_type
      subnet_ids       = config.subnet_ids
    }
  }

  tags = merge({
    Owner = "arpegezz",
  }, var.tags)
}


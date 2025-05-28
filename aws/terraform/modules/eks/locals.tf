locals {
  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  authentication_mode         = var.authentication_mode
  create_kms_key              = var.create_kms_key
  cluster_encryption_config   = local.create_kms_key ? [] : []
  create_cloudwatch_log_group = var.create_cloudwatch_log_group

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  admin_access_entries = {
    cluster_admin = {
      principal_arn = "arn:aws:iam::329599650491:user/eks-admin"
      policy_associations = {
        admin_policy = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  access_entries = merge(
    local.admin_access_entries,
    var.additional_access_entries,
  )

  cluster_addons = var.cluster_addons

  tags = merge({}, var.tags)

  # ============= node group ===============
  default_node_group_policies = [
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly"
  ]

  additional_node_group_policies = var.additional_node_group_policies
  combined_policies = concat(
    local.default_node_group_policies,
    local.additional_node_group_policies,
  )

  nodegroup_policies = distinct(local.combined_policies)

  default_node_group_configs = {
    create_iam_role                 = false
    iam_role_use_name_prefix        = true
    use_name_prefix                 = true
    labels                          = null
    taints                          = null
    tags                            = null
    ami_type                        = "AL2_x86_64"
    disable_api_termination         = false
    ebs_optimized                   = true
    enable_monitoring               = false
    launch_template_use_name_prefix = true
  }

  node_group_configs = {
    for ng_key, ng in var.node_group_configs : ng_key => {
      # mandatory fields
      name           = ng_key
      min_size       = ng.min_size
      max_size       = ng.max_size
      desired_size   = ng.desired_size
      disk_size      = ng.disk_size
      instance_types = ng.instance_types
      capacity_type  = ng.capacity_type

      # optional fields
      use_name_prefix                 = coalesce(ng.use_name_prefix, local.default_node_group_configs.use_name_prefix)
      create_iam_role                 = coalesce(ng.create_iam_role, local.default_node_group_configs.create_iam_role)
      iam_role_use_name_prefix        = coalesce(ng.iam_role_use_name_prefix, local.default_node_group_configs.iam_role_use_name_prefix)
      labels                          = coalesce(ng.labels, local.default_node_group_configs.labels)
      taints                          = coalesce(ng.taints, local.default_node_group_configs.taints)
      tags                            = coalesce(ng.tags, local.default_node_group_configs.tags)
      ami_type                        = coalesce(ng.ami_type, local.default_node_group_configs.ami_type)
      disable_api_termination         = coalesce(ng.disable_api_termination, local.default_node_group_configs.disable_api_termination)
      ebs_optimized                   = coalesce(ng.ebs_optimized, local.default_node_group_configs.ebs_optimized)
      enable_monitoring               = coalesce(ng.enable_monitoring, local.default_node_group_configs.enable_monitoring)
      launch_template_name            = coalesce(ng.launch_template_name, format("%s-lt", upper(ng_key)))
      launch_template_use_name_prefix = coalesce(ng.launch_template_use_name_prefix, local.default_node_group_configs.launch_template_use_name_prefix)
    }
  }

  vpc_cni_helm_install = var.vpc_cni_helm_install

  nat_cidrs          = var.cluster_endpoint_public_access ? ["3.34.211.206/32"] : []
  extra_public_cidrs = var.extra_public_cidrs
  public_access_cidrs = distinct(
    concat(
      local.extra_public_cidrs,
      local.nat_cidrs,
    )
  )
  cluster_endpoint_public_access_cidrs = length(local.public_access_cidrs) > 0 ? local.public_access_cidrs : null
}

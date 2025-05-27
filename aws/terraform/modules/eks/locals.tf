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

  access_entries = {}
  # {
  #   cluster_admin = {
  #     principal_arn = "arn:aws:iam::329599650491:user/ggorockee_saa_03"
  #     policy_associations = {
  #       admin_policy = {
  #         policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #         access_scope = { type = "cluster" }
  #       }
  #     }
  #   }
  # }

  base_cluster_addons = {
    coredns                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
  }

  cluster_addons = merge(
    local.base_cluster_addons,
    var.cluster_addons
  )

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
    create_iam_role          = false
    iam_role_use_name_prefix = true
    use_name_prefix          = true
    labels                   = {}
    taints                   = {}
    tags                     = {}
    ami_type                 = "AL2_x86_64"
    disable_api_termination  = false
    ebs_optimized            = true
    enable_monitoring        = false
  }

  node_group_configs = {
    for ng_key, ng in var.node_group_configs : ng_key => merge(local.default_node_group_configs, {
      name                     = ng_key
      use_name_prefix          = ng.use_name_prefix
      create_iam_role          = ng.create_iam_role
      iam_role_use_name_prefix = ng.iam_role_use_name_prefix
      min_size                 = ng.min_size
      max_size                 = ng.max_size
      desired_size             = ng.desired_size
      disk_size                = ng.disk_size
      instance_types           = ng.instance_types
      capacity_type            = ng.capacity_type
      labels                   = ng.labels
      taints                   = ng.taints
      tags                     = ng.tags
      ami_type                 = ng.ami_type
      disable_api_termination  = ng.disable_api_termination
      ebs_optimized            = ng.ebs_optimized
      enable_monitoring        = ng.enable_monitoring
    })
  }
}

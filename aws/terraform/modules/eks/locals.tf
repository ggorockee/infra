locals {
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  tags            = merge({}, var.tags)
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  default_policies_ = [
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
  ]

  combined_policies = concat(
    local.default_policies_,
    var.additional_default_policy
  )

  default_policies = distinct(local.combined_policies)
  attachments = flatten([
    for ng_key, ng in module.eks.eks_managed_node_groups : [
      for policy in local.default_policies : {
        ng_key    = ng_key
        policy    = policy
        role_name = ng.iam_role_name
      }
    ]
  ])

  attachment_map = {
    for att in local.attachments :
    "${att.ng_key}-${att.policy}" => att
  }
}

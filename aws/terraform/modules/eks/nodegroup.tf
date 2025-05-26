module "eks_managed_node_group" {
  source   = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  for_each = local.node_group_configs


  cluster_name                      = local.cluster_name
  cluster_version                   = local.cluster_version
  version                           = "20.36.0"
  subnet_ids                        = local.subnet_ids
  cluster_service_cidr              = module.eks.cluster_service_cidr
  create_iam_role                   = local.create_iam_role
  iam_role_arn                      = aws_iam_role.eks_node_group_role.arn
  iam_role_name                     = aws_iam_role.eks_node_group_role.name
  iam_role_use_name_prefix          = local.iam_role_use_name_prefix
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]


  name            = upper(each.value.name)
  use_name_prefix = each.value.use_name_prefix


  min_size     = each.value.min_size
  max_size     = each.value.max_size
  desired_size = each.value.desired_size

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type

  labels = each.value.labels
  taints = each.value.taints
  tags   = each.value.tags
}
module "eks_managed_node_group" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

  name            = upper(local.node_group.name)
  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version
  version         = "20.36.0"

  subnet_ids               = local.subnet_ids
  cluster_service_cidr     = module.eks.cluster_service_cidr
  create_iam_role          = local.create_iam_role
  iam_role_arn             = aws_iam_role.eks_node_group_role.arn
  iam_role_name            = aws_iam_role.eks_node_group_role.name
  iam_role_use_name_prefix = local.iam_role_use_name_prefix

  // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
  // Without it, the security groups of the nodes are empty and thus won't join the cluster.
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

  // Note: `disk_size`, and `remote_access` can only be set when using the EKS managed node group default launch template
  // This module defaults to providing a custom launch template to allow for custom security groups, tag propagation, etc.
  // use_custom_launch_template = false
  // disk_size = 50
  //
  //  # Remote access cannot be specified with a launch template
  //  remote_access = {
  //    ec2_ssh_key               = module.key_pair.key_pair_name
  //    source_security_group_ids = [aws_security_group.remote_access.id]
  //  }

  min_size     = local.node_group.min_size
  max_size     = local.node_group.max_size
  desired_size = local.node_group.desired_size

  instance_types = local.node_group.instance_types
  capacity_type  = local.node_group.capacity_type

  labels = local.node_group.labels
  taints = local.node_group.taints
  tags   = local.node_group.tags
}
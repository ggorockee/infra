module "eks_managed_node_group" {
  source   = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  for_each = local.node_group_configs


  cluster_name         = local.cluster_name
  cluster_version      = local.cluster_version
  version              = "20.36.0"
  subnet_ids           = local.subnet_ids
  cluster_service_cidr = module.eks.cluster_service_cidr
  iam_role_arn         = aws_iam_role.eks_node_group_role.arn
  iam_role_name        = aws_iam_role.eks_node_group_role.name

  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

  create_iam_role                 = each.value.create_iam_role
  iam_role_use_name_prefix        = each.value.iam_role_use_name_prefix
  name                            = upper(each.value.name)
  use_name_prefix                 = each.value.use_name_prefix
  min_size                        = each.value.min_size
  max_size                        = each.value.max_size
  desired_size                    = each.value.desired_size
  instance_types                  = each.value.instance_types
  capacity_type                   = each.value.capacity_type
  labels                          = each.value.labels
  taints                          = each.value.taints
  tags                            = each.value.tags
  disk_size                       = each.value.disk_size
  ami_type                        = each.value.ami_type
  launch_template_use_name_prefix = each.value.launch_template_use_name_prefix
  launch_template_name            = each.value.launch_template_name
}

data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_node_group_role" {
  name               = upper("${local.cluster_name}-eks-managed-node-group-role")
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
}

resource "aws_iam_role_policy_attachment" "node_group" {
  for_each   = toset(local.nodegroup_policies)
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}

resource "aws_eks_access_entry" "managed_node_roles" {
  for_each      = module.eks.eks_managed_node_groups
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value.iam_role_arn
  type          = "EC2_LINUX"
}

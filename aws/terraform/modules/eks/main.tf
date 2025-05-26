module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.36.0"
  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version

  cluster_endpoint_public_access  = local.cluster_endpoint_public_access
  cluster_endpoint_private_access = local.cluster_endpoint_private_access

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  tags        = local.tags
  enable_irsa = local.enable_irsa # false

  create_iam_role = local.create_iam_role
  iam_role_name   = aws_iam_role.eks_cluster_role.name
  iam_role_arn    = aws_iam_role.eks_cluster_role.arn

  cluster_addons              = local.cluster_addons
  create_kms_key              = local.create_kms_key
  cluster_encryption_config   = local.create_kms_key ? [] : []
  create_cloudwatch_log_group = local.create_cloudwatch_log_group

}
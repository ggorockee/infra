locals {
  # region
  region = data.aws_region.current.name

  # tag
  tags = merge({
    Managed_by = "Terraform"
  }, var.tags)

  # API 엔드포인트 접근 제어
  cluster_endpoint_private_access = var.cluster_endpoint_private_access # true
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access  # false

  cluster_version         = var.cluster_version
  cluster_name            = upper(var.cluster_name)
  vpc_id                  = var.vpc_id
  subnet_ids              = var.subnet_ids
  eks_managed_node_groups = var.eks_managed_node_groups

  additional_security_groups = var.additional_security_groups
  enable_irsa                = var.enable_irsa

  cluster_addons_ = {
    "vpc-cni" = {
      addon_name        = "vpc-cni"
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }

    "aws-ebs-csi-driver" = {
      addon_name        = "aws-ebs-csi-driver"
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }

    "coredns" = {
      addon_name        = "coredns"
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }

    "metrics-server" = {
      addon_name        = "metrics-server"
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
  }

  cluster_addons              = merge(local.cluster_addons_, var.cluster_addons)
  create_kms_key              = var.create_kms_key
  create_cloudwatch_log_group = var.create_cloudwatch_log_group

  node_group = {
    name           = var.node_group.node_group_name
    min_size       = var.node_group.min_size
    max_size       = var.node_group.max_size
    desired_size   = var.node_group.desired_size
    instance_types = var.node_group.instance_types # ["t3.large"]
    capacity_type  = var.node_group.capacity_type  # SPOT

    labels = merge({
      Environment = "test"
      GithubRepo  = "terraform-aws-eks"
      GithubOrg   = "terraform-aws-modules"
    }, var.node_group.labels)

    taints = merge({}, var.node_group.taints)
    tags = merge(
      {
        Environment = "dev"
        Terraform   = "true"
    }, var.tags)
  }















  # aws-auth ConfigMap 자동 관리 해제 (AssumeRole 방식)
  # manage_aws_auth = var.manage_aws_auth # false

  # # IRSA/OIDC 사용
  # enable_irsa = var.enable_irsa # true

  # # CloudWatch Logs 비활성화
  # create_cloudwatch_log_group = var.create_cloudwatch_log_group # false

  # access_entries = {
  #   cluster_assume_role = {
  #     principal_arn = aws_iam_role.eks_cluster.arn
  #     type          = "STANDARD"
  #   }
  # }

  # base_addons = var.cluster_addons

  # csi_addon = length(var.ebs_csi_irsa_roles) > 0 ? {
  #   "aws-ebs-csi-driver" = {
  #     most_recent              = true
  #     resolve_conflicts        = "PRESERVE"
  #     service_account_role_arn = module.ebs_csi_irsa_role[keys(var.ebs_csi_irsa_roles)[0]].iam_role_arn
  #   }
  # } : {}

  # cluster_addons = merge(local.base_addons, local.csi_addon)
}
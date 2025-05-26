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

    #    "aws-ebs-csi-driver" = {
    #      addon_name        = "aws-ebs-csi-driver"
    #      most_recent       = true
    #      resolve_conflicts = "OVERWRITE"
    #    }

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

  node_group_configs = {
    for ng_key, ng in var.node_group : ng_key => {
      name            = ng_key
      min_size        = ng.min_size
      max_size        = ng.max_size
      desired_size    = ng.desired_size
      instance_types  = ng.instance_types
      capacity_type   = ng.capacity_type
      use_name_prefix = ng.use_name_prefix

      labels = merge(
        {
          Environment = "test"
          GithubRepo  = "terraform-aws-eks"
          GithubOrg   = "terraform-aws-modules"
        },
        ng.labels
      )
      taints = ng.taints

      tags = merge(
        {
          Environment = "dev"
          Terraform   = "true"
        },
        var.tags, # 공통 태그
        ng.tags   # 노드그룹별 추가 태그
      )
    }
  }

  create_iam_role = var.create_iam_role
  node_group_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]

  eks_cluster_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy", # 클러스터 생성·관리 권한
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy", # 내부 컨트롤플레인 
  ]

  iam_role_use_name_prefix = var.iam_role_use_name_prefix

}
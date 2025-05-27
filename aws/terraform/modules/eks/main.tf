module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name                    = "ggorockee-eks-cluster"
  cluster_version                 = "1.32"
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  authentication_mode = "API"

  # 관리자(entry)만 미리 정의
  access_entries = {
    cluster_admin = {
      principal_arn = "arn:aws:iam::329599650491:user/ggorockee_saa_03"
      policy_associations = {
        admin_policy = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  # EKS Addons
  cluster_addons = {
    coredns                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni = {
      most_recent = true
      disable     = true
    }
  }

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  create_kms_key              = false
  cluster_encryption_config   = []
  create_cloudwatch_log_group = false

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2_x86_64"
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      instance_types = ["t3.micro"]

      subnet_ids = local.subnet_ids
      disk_size  = 20

      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = true

      create_iam_role          = true
      iam_role_name            = "ggorock-test-eks-managed-node-group"
      iam_role_use_name_prefix = false
      iam_role_description     = "EKS test managed node group"
      iam_role_tags = {
        Purpose = "Protector of the kubelet"
      }

      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        additional                         = aws_iam_policy.node_additional.arn
      }
    }
  }

  tags = local.tags
}

resource "aws_eks_access_entry" "managed_node_roles" {
  for_each      = module.eks.eks_managed_node_groups
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value.iam_role_arn
  type          = "EC2_LINUX"
}

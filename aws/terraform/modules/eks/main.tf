module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name                    = "ggorockee-eks-cluster"
  cluster_version                 = "1.32"
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # EKS Addons
  cluster_addons = {
    coredns                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
  }

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  eks_managed_node_groups = {
    default = {
      min_size     = 2
      max_size     = 2
      desired_size = 2

      ami_id     = data.eks_default.imag_id
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

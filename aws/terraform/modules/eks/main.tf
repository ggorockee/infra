module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name                    = "ggorockee-eks-cluster"
  cluster_version                 = "1.32"
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # EKS Addons
  cluster_addons = {
    coredns                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni = {
      most_recent              = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
  }

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  create_kms_key              = false
  cluster_encryption_config   = []
  create_cloudwatch_log_group = false

  eks_managed_node_groups = {
    default = {
      ami_type   = "AL2_x86_64"
      min_size     = 1
      max_size     = 1
      desired_size = 1
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

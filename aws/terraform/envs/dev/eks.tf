

module "eks" {
  source             = "../../modules/eks"
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  eks_cluster_name   = "arpegezz-eks-cluster"
  eks_version        = "1.31"
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  using_nat = false

  self_managed_node_groups = {
    ARPEGEZZ-NODEGROUP = {
      name             = "ARPEGEZZ-NODEGROUP"
      max_capacity     = 2
      desired_capacity = 1
      min_capacity     = 1
      instance_type    = "t3.micro"
      subnet_ids       = data.terraform_remote_state.network.outputs.private_subnet_ids
    }
  }

  worker_policies = [
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
  ]

  auto_scaling_config = {
    ARPEGEZZ-NODEGROUP = {
      name             = "ARPEGEZZ-AUTOSCALING-GROUP"
      desired_capacity = 1
      min_size         = 1
      max_size         = 2
      subnet_ids       = data.terraform_remote_state.network.outputs.private_subnet_ids
    }
  }
  tags = {
    Owner      = "arpegezz"
    Managed_By = "Terraform"
  }



  enable_irsa = true

  cluster_addons = {
    coredns = {
      addon_version = "v1.13.5-eksbuild.3"
    }

    kube-proxy = {
      addon_version = "v1.31.2-eksbuild.1"
    }

    vpc-cni = {
      addon_version = "v1.19.3-eksbuild.2"
    }

    eks-pod-identity-agent = {
      addon_version = null
    }
  }

  iam_access_entries = {
    SSO = {
      arns = ["arn:aws:iam::329599650491:user/ggorockee_saa_03"]
    }
  }

  additional_eks_managed_policyment = ["AmazonEKSClusterPolicy"]

  authentication_mode = "API"

  cluster_security_group_additional_rules = {
    ingress_from_specific_cidr = {
      description = "Allow All TCP from specific CIDR"
      protocol    = "tcp"
      from_port   = 1
      to_port     = 65535
      type        = "ingress"
      cidr_blocks = ["10.0.1.16/32"]
    }
  }

  node_security_group_additional_rules = {
    egress_all = {
      description = "Allow all outbound traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  cluster_enabled_log_types   = []
  cluster_encryption_config   = []
  create_cloudwatch_log_group = false
}

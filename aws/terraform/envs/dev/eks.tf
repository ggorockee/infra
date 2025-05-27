module "eks" {
  source = "../../modules/eks"

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  tags = {
    ManagedBy = "Terraform"
  }
  cluster_name    = "ggorockee-eks-cluster"
  cluster_version = "1.32"


  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true
  create_kms_key                  = false
  create_cloudwatch_log_group     = false

  authentication_mode = "API"

  access_entries = {}
  #   cluster_admin = {
  #     principal_arn = "arn:aws:iam::329599650491:user/ggorockee_saa_03"
  #     policy_associations = {
  #       admin_policy = {
  #         policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #         access_scope = { type = "cluster" }
  #       }
  #     }
  #   }
  # }

  cluster_addons = {
    eks-pod-identity-agent = {
      disable = true
    }

    vpc-cni = {
      disable = true
    }
  }

  node_group_configs = {
    ggorockee-default-node-group = {
      use_name_prefix          = false
      iam_role_use_name_prefix = false
      min_size                 = 1
      max_size                 = 1
      desired_size             = 1
      disk_size                = 10
      instance_types           = ["t3.micro"]
      capacity_type            = "SPOT"
      labels                   = {}
      taints                   = {}
      tags                     = {}
    }
  }
}

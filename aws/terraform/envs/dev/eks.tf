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

  additional_access_entries = {}

  cluster_addons = {
    "coredns" = {
      most_recent = true
      configuration_values = jsonencode({
        replicaCount = 1
      })
    }

    "vpc-cni"    = { most_recent = true }
    "kube-proxy" = { most_recent = true }
  }
  vpc_cni_helm_install = false

  node_group_configs = {
    ggorockee-default-node-group = {
      use_name_prefix                 = false
      iam_role_use_name_prefix        = false
      min_size                        = 1
      max_size                        = 1
      desired_size                    = 1
      disk_size                       = 10
      instance_types                  = ["t3.small"]
      capacity_type                   = "SPOT"
      launch_template_use_name_prefix = false
      # labels                          = {}
      # taints                          = {}
      # tags                            = {}

    }
  }

  auto_scaling_configs = {}
}

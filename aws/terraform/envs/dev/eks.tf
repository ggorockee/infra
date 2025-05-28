module "eks" {
  source = "../../modules/eks"

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  tags = {
    ManagedBy = "Terraform"
  }
  cluster_name    = "ggorockee-eks-cluster"
  cluster_version = "1.32"


  cluster_endpoint_public_access = true
  extra_public_cidrs = [
    "0.0.0.0/0"
  ]
  cluster_endpoint_private_access = true
  create_kms_key                  = false
  create_cloudwatch_log_group     = false

  authentication_mode = "API"

  additional_access_entries = {}

  cluster_addons       = {}
  vpc_cni_helm_install = true

  node_group_configs = {
    ggorockee-default-node-group = {
      use_name_prefix                 = false
      iam_role_use_name_prefix        = false
      min_size                        = 1
      max_size                        = 1
      desired_size                    = 1
      disk_size                       = 10
      instance_types                  = ["t3.micro"]
      capacity_type                   = "SPOT"
      labels                          = {}
      taints                          = {}
      tags                            = {}
      launch_template_use_name_prefix = false
    }
  }
}

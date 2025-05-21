# authentication_mode = "API"
# cluster_policies = [
#   "AmazonEKSClusterPolicy",
#   "AmazonEKSServicePolicy"
# ]

module "eks" {
  source = "../../modules/eks"
  cluster_name = "arpegezz-es-cluster"
  cluster_version = "1.31"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  self_managed_node_groups = {
    ARPEGEZZ_NODEGROUP = {
      instance_type         = "t3.micro"
     asg_desired_capacity  = 1
     asg_min_size          = 1
      asg_max_size          = 2
      disk_size             = 10
    }
  }
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access = false
  manage_aws_auth = false
  enable_irsa = true
  create_cloudwatch_log_group = false
  authentication_mode = "API"
  using_nat = false
}
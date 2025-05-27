module "eks" {
  source = "../../modules/eks"

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  tags = {
    ManagedBy = "Terraform"
  }
  cluster_name    = "ggorockee-eks-cluster"
  cluster_version = "1.32"

}

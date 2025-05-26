# module "eks" {
#   source = "../../modules/eks"

#   cluster_name    = var.eks_cluster_name
#   cluster_version = "1.31"

#   cluster_endpoint_public_access  = false
#   cluster_endpoint_private_access = true

#   vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
#   subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids


#   enable_irsa                 = true
#   cluster_addons              = {}
#   additional_security_groups  = {}
#   create_cloudwatch_log_group = false
#   create_kms_key              = false
#   create_iam_role             = false
#   iam_role_use_name_prefix    = false

#   node_group = {
#     default = {
#       use_name_prefix = false
#       min_size        = 1
#       max_size        = 2
#       desired_size    = 1
#       instance_types  = ["t3.micro"]
#       capacity_type   = "SPOT"
#       labels          = {}
#       taints          = {}
#       tags            = {}
#     }
#   }
# }

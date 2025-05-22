
module "eks" {
  source             = "../../modules/eks"
  cluster_name       = "arpegezz-es-cluster"
  cluster_version    = "1.31"
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  self_managed_node_groups = {
    ARPEGEZZ_NODEGROUP = {
      instance_type        = "t3.micro"
      asg_desired_capacity = 1
      asg_min_size         = 1
      asg_max_size         = 2
      disk_size            = 10
    }
  }
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false
  manage_aws_auth                 = false
  enable_irsa                     = true
  create_cloudwatch_log_group     = false
  authentication_mode             = "API"
  using_nat                       = false
  create_kms_key                  = false
  cluster_encryption_config       = []

  ebs_csi_irsa_roles = {
    default = {
      create_role       = true
      role_name         = "arpegezz-eks-cluster-ebs-csi-controller"
      oidc_fully_qualified_subjects = [
        "system:serviceaccount:kube-system:ebs-csi-controller-sa"
      ]
  } }

  cluster_addons = {
    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    "vpc-cni" = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
  }

  additional_security_groups = {
    ACCESS = {
      name   = "EKS-API-ACCESS"
      vpc_id = data.terraform_remote_state.network.outputs.vpc_id
      tags = {
        Name = "EKS-API-ACCESS"
      }
      ingress = {
        description = "Allow EKS API"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["${var.OPENVPN_IP}/32"]
      }
      egress = {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
  }
}
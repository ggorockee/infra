variable "tags" {
  type    = map(string)
  default = {}
}

variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "cluster_version" {
  description = "EKS 버전"
  type        = string
  default     = "1.31"
}


variable "vpc_id" {
  description = "기존 VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "EKS 노드를 위한 subnet IDs"
  type        = list(string)
}

variable "eks_managed_node_groups" {
  type = map(object({
    ami_type        = string
    instance_types  = list(string)
    name            = string
    use_name_prefix = bool
    disk_size       = number
    min_size        = number
    max_size        = number
    desired_size    = number
  }))
  default = {}
  #  default = {
  #    default = {
  #      ami_type        = "AL2_x86_64"
  #      instance_types  = ["t3.micro"]
  #      name            = "GGOROCKEE_NODEGROUP"
  #      use_name_prefix = false
  #      disk_size       = 20
  #      min_size        = 1
  #      max_size        = 2
  #      desired_size    = 1
  #    }
  #  }
}

# variable "private_route_table_ids" {
#   description = "S3 Gateway Endpoint를 위한 private route table IDs"
#   type        = list(string)
#   default     = []
# }

# variable "vpce_security_group_ids" {
#   description = "Interface Endpoint에 붙일 Security Group IDs"
#   type        = list(string)
#   default     = []
# }

# variable "self_managed_node_groups" {
#   description = "Self-managed node group definitions (map of objects)"
#   type = map(object({
#     instance_type        = string
#     asg_desired_capacity = number
#     asg_min_size         = number
#     asg_max_size         = number
#     disk_size            = number
#     # key_name, labels, tags 등 추가 필드도 가능
#   }))
#   default = {}
# }

variable "cluster_endpoint_private_access" {
  type = bool
}
variable "cluster_endpoint_public_access" {
  type = bool
}
# variable "manage_aws_auth" {
#   type = bool
# }
# variable "enable_irsa" {
#   type = bool
# }

# variable "create_cloudwatch_log_group" {
#   type = bool
# }
# variable "authentication_mode" {
#   type = string
# }



# variable "cluster_policies" {
#   type = list(string)
#   default = [
#     "AmazonEKSClusterPolicy",
#     "AmazonEKSServicePolicy"
#   ]
# }

# variable "create_kms_key" {
#   type = bool
# }

# variable "cluster_encryption_config" {
#   description = "EKS 클러스터 암호화 설정 (resources, provider_key_arn)"
#   type = list(object({
#     resources        = list(string)
#     provider_key_arn = string
#   }))
#   default = []
# }

# variable "ebs_csi_irsa_roles" {
#   description = "ebs csi driver 설정"
#   type = map(object({
#     create_role                   = bool
#     role_name                     = string
#     oidc_fully_qualified_subjects = list(string)
#   }))
#   default = {}
# }

# variable "cluster_addons" {
#   description = "custer addons"
#   type = map(object({
#     most_recent              = optional(bool, false)
#     resolve_conflicts        = optional(string, "OVERWRITE")
#     service_account_role_arn = optional(string, "")
#   }))
# }

variable "additional_security_groups" {
  description = "Map of extra security groups to create for EKS"
  type = map(object({
    name        = string
    description = string
    ingress = list(object({
      description     = string
      from_port       = number
      to_port         = number
      protocol        = string
      cidr_blocks     = list(string)
      security_groups = optional(list(string), [])
    }))
    egress = list(object({
      description     = string
      from_port       = number
      to_port         = number
      protocol        = string
      cidr_blocks     = list(string)
      security_groups = optional(list(string), [])
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "cluster_role_name" {
  description = "Name for the EKS cluster IAM role"
  type        = string
  default     = null
}

variable "manage_cluster_iam_resources" {
  type    = bool
  default = true
}

variable "enable_irsa" {
  type    = bool
  default = false
}

variable "cluster_addons" {
  type = map(any)
}

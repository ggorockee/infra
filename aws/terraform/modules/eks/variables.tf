variable "vpc_id" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "eks_version" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_endpoint_public_access" {
  type = bool
}

variable "cluster_endpoint_private_access" {
  type = bool
}

variable "self_managed_node_groups" {
  type = map(object({
    name             = string       # ARPEGEZZ-NODEGROUP
    desired_capacity = number       # 1
    max_capacity     = number       # 2
    min_capacity     = number       # 1
    instance_type    = string       # "t3.micro"
    subnet_ids       = list(string) # subnet
  }))
}

variable "tags" {
  type = map(string)
}

variable "enable_irsa" {
  type = bool
}

variable "authentication_mode" {
  type        = string
  description = "API|API_AND_CONFIG_MAP|CONFIG_MAP"
}

variable "default_addon_versions" {
  description = "기본 애드온 버전"
  type = object({
    coredns                = string
    kube-proxy             = string
    vpc-cni                = string
    eks-pod-identity-agent = string
  })
  default = {
    coredns                = "v1.13.5-eksbuild.3"
    kube-proxy             = "v1.31.2-eksbuild.1"
    vpc-cni                = "v1.19.3-eksbuild.2"
    eks-pod-identity-agent = null # "v1.3.0-eksbuild.1"
  }
}

variable "cluster_addons" {
  description = "EKS 클러스터 애드온 구성"
  type = map(object({
    addon_version        = optional(string, null)
    resolve_conflicts    = optional(string, "OVERWRITE")
    configuration_values = optional(string, null)
    tags                 = optional(map(string), {})
    most_recent          = optional(bool, false)
  }))
  default = {}
}

# variable "access_entries" {
#   description = "Access entries for IAM roles and their policy associations"
#   type = map(object({
#     principal_arn = string
#     policy_associations = map(object({
#       policy_arn = string
#     }))
#   }))
#   default = {}
# }

variable "iam_access_entries" {
  description = "Key: SSO, ROLE"
  type = map(object({
    arns = optional(list(string), [])
  }))
}

variable "additional_eks_managed_policyment" {
  description = "AmazonEKSClusterAdminPolicy | ..."
  type        = list(string)
  default     = []
}

variable "eks_access_entries" {
  description = "EKS access entries configuration"
  type        = map(any)
  default     = {}
}

variable "cluster_security_group_additional_rules" {
  description = "Additional rules for the cluster security group"
  type        = map(any)
  default     = {}
}

variable "node_security_group_additional_rules" {
  description = "Additional rules for the node security group"
  type        = map(any)
  default     = {}
}

variable "cluster_enabled_log_types" {
  type = list(string)
}
variable "cluster_encryption_config" {
  type = list(any)
}

variable "create_cloudwatch_log_group" {
  type = bool
}

variable "using_nat" {
  type = bool
}

variable "worker_policies" {
  type = list(string)
}

variable "auto_scaling_config" {
  type = map(object({
    name             = string
    desired_capacity = number
    min_size         = number
    max_size         = number
    subnet_ids       = optional(list(string), [])
  }))
}

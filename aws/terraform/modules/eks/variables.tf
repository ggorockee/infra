variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "tags" {
  type = map(string)
}
variable "cluster_name" {
  type = string
}
variable "cluster_version" {
  type = string
}
variable "cluster_endpoint_public_access" {
  type = bool
}
variable "cluster_endpoint_private_access" {
  type = bool
}
variable "create_kms_key" {
  type = bool
}

variable "create_cloudwatch_log_group" {
  type = string
}
variable "authentication_mode" {
  type = string
}
variable "access_entries" {
  type = map(any)
}
variable "cluster_addons" {
  type = map(any)
}

variable "node_group_configs" {
  type = map(object({
    min_size                        = number
    max_size                        = number
    desired_size                    = number
    disk_size                       = number
    instance_types                  = list(string)
    capacity_type                   = string
    use_name_prefix                 = optional(bool, null)
    create_iam_role                 = optional(bool, null)
    iam_role_use_name_prefix        = optional(bool, null)
    labels                          = optional(map(string), null)
    taints                          = optional(map(string), null)
    tags                            = optional(map(string), null)
    ami_type                        = optional(string, null)
    disable_api_termination         = optional(bool, false)
    ebs_optimized                   = optional(bool, true)
    enable_monitoring               = optional(bool, true)
    launch_template_name            = optional(string, null)
    launch_template_use_name_prefix = optional(bool, null)
  }))
}

variable "additional_node_group_policies" {
  type    = list(string)
  default = []
}

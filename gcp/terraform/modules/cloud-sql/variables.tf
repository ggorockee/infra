variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast3"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_network_id" {
  description = "VPC Network ID for Private IP configuration"
  type        = string
}

variable "instance_tier" {
  description = "Cloud SQL instance tier"
  type        = string
  default     = "db-g1-small" # 1 vCPU, 1.7GB RAM
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "deletion_protection" {
  description = "Enable deletion protection for production"
  type        = bool
  default     = true
}

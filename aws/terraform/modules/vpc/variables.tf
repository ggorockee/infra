variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "private_subnets" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.0.100.0/23", "10.0.102.0/23"]
}

variable "azs" {
  description = "가용 영역 목록"
  type        = list(string)
  default     = ["ap-northeast-2c"]
}

variable "private_azs" {
  description = "가용 영역 목록"
  type        = list(string)
  default     = ["ap-northeast-2c", "ap-northeast-2a"]
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}

variable "username" {
  description = "username"
  type        = string
  default     = "arpegez"
}

variable "owner" {
  description = "owner"
  type        = string
  default     = "arpegezz"
}

variable "eks_cluster_name" {
  type    = string
  default = ""
}
variable "region" {
  default = "ap-northeast-2" # 원하는 리전으로 변경
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "subnet_ids" {
  description = "VPC 엔드포인트를 생성할 서브넷 ID 목록"
  type        = list(string)
}

locals {
  ssm_endpoints = ["ssm", "ssmmessages", "ec2messages"]
}



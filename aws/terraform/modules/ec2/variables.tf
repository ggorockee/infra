variable "instance_name" {
  type        = string
  description = "인스턴스 이름 태그"
}

variable "ami_id" {
  type        = string
  description = "AMI ID"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "subnet_id" {
  type        = string
  description = "서브넷 ID"
}

variable "existing_sg_id" {
  description = "기존 보안 그룹 ID (선택 사항)"
  type        = string
  default     = ""
}

variable "sg_name" {
  description = "보안 그룹 이름"
  type        = string
  default     = "ec2-security-group"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "security_group_ingress" {
  type = map(object({
    description = string
    protocol    = string
    from_port   = number
    to_port     = number
    cidr_blocks = list(string)
  }))
}

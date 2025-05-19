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
    description     = string
    protocol        = string
    from_port       = number
    to_port         = number
    cidr_blocks     = optional(list(string))
    security_groups = optional(list(string))
  }))
}


variable "root_block_device" {
  type = object({
    volume_type           = string               # gp3, gp2, io1, io2, st1, sc1 등
    volume_size           = number               # GiB 단위, 예: 30GiB
    iops                  = optional(number)     # gp3/io1/io2에서만 사용, 필요시 지정
    throughput            = optional(number)     # gp3에서만 사용, 필요시 지정
    delete_on_termination = optional(bool, true) # 인스턴스 종료 시 EBS 삭제
  })
}

variable "ebs_block_device" {
  type = map(object({
    volume_type           = string               # gp3, gp2, io1, io2, st1, sc1 등
    volume_size           = number               # GiB 단위, 예: 30GiB
    iops                  = optional(number)     # gp3/io1/io2에서만 사용, 필요시 지정
    throughput            = optional(number)     # gp3에서만 사용, 필요시 지정
    delete_on_termination = optional(bool, true) # 인스턴스 종료 시 EBS 삭제
  }))
}


variable "iam_instance_profile" {
  type    = string
  default = ""
}

variable "vpc_id" {
  type = string
}

variable "use_spot" {
  description = "Whether to use a Spot Instance"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "Instance type for ec2"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "key_pair_name"
  type        = string
  default     = ""
}

variable "root_block_device" {
  description = "EBS root block device 설정"
  type = object({
    volume_size           = number
    volume_type           = string
    delete_on_termination = optional(bool, true)
    iops                  = optional(number)
    throughput            = optional(number)
  })
  default = {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    # iops, throughput 필드는 필요 시 주석 해제
    # iops       = 3000
    # throughput = 125
  }
}

variable "instance_market_options" {
  description = "instance_market_options"
  type = object({
    market_type                    = string
    instance_interruption_behavior = string
    spot_instance_type             = string
  })
  default = {
    market_type                    = "spot"
    instance_interruption_behavior = "stop"
    spot_instance_type             = "persistent"
  }
}

variable "owner" {
  type    = string
  default = "arpegezz"
}


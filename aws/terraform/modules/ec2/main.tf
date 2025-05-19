
# 기존 SG 조회 (ID가 제공된 경우)
data "aws_security_group" "existing" {
  count = var.existing_sg_id != "" ? 1 : 0
  id    = var.existing_sg_id
}


# 새 SG 생성 (ID가 제공되지 않은 경우)
resource "aws_security_group" "new" {
  count  = var.existing_sg_id == "" ? 1 : 0
  name   = var.sg_name
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.security_group_ingress
    content {
      from_port       = length(ingress.value["from_port"]) > 0 ? ingress.value["from_port"] : null
      to_port         = length(ingress.value["to_port"]) > 0 ? ingress.value["to_port"] : null
      protocol        = length(ingress.value["protocol"]) > 0 ? ingress.value["protocol"] : null
      description     = length(ingress.value["description"]) > 0 ? ingress.value["description"] : null
      cidr_blocks     = length(ingress.value["cidr_blocks"]) > 0 ? ingress.value["cidr_blocks"] : null
      security_groups = length(ingress.value["security_groups"]) > 0 ? ingress.value["security_groups"] : null
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 최종 SG ID 결정
locals {
  final_sg_id = var.existing_sg_id != "" ? var.existing_sg_id : aws_security_group.new[0].id
}

# EC2 인스턴스 생성
resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [local.final_sg_id]
  iam_instance_profile   = var.iam_instance_profile != "" ? var.iam_instance_profile : null




  dynamic "ebs_block_device" {
    for_each = var.ebs_block_device
    content {
      device_name = ebs_block_device.value.device_name
      volume_size = ebs_block_device.value.volume_size
      volume_type = ebs_block_device.value.volume_type
    }
  }


  root_block_device {
    volume_type           = var.root_block_device.volume_type
    volume_size           = var.root_block_device.volume_size
    iops                  = var.root_block_device.iops
    throughput            = var.root_block_device.throughput
    delete_on_termination = var.root_block_device.delete_on_termination
  }

  tags = {
    Name = var.instance_name
  }
}

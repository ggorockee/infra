
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
      from_port   = ingress.value["from_port"]
      to_port     = ingress.value["to_port"]
      protocol    = ingress.value["protocol"]
      description = ingress.value["description"]
      cidr_blocks = ingress.value["cidr_blocks"]
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

  tags = {
    Name = var.instance_name
  }
}

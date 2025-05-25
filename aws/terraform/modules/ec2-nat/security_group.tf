resource "aws_security_group" "nat" {
  name        = upper("nat-sg-${local.owner}")
  description = "Allow traffic from private subnets to NAT"
  vpc_id      = local.vpc.id

  # NAT → 인터넷 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = upper("nat-sg-${local.owner}")
  }
}

resource "aws_security_group_rule" "allow_all_ingress" {
  type              = "ingress" # ingress / egress
  description       = "VPC"
  security_group_id = aws_security_group.nat.id
  protocol          = "-1" # All traffic
  from_port         = 0
  to_port           = 0
  cidr_blocks       = [local.vpc.cidr]
}
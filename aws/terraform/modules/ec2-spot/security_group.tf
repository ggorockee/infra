resource "aws_security_group" "nat" {
  name        = upper("nat-sg-${local.owner}")
  description = "Allow traffic from private subnets to NAT"
  vpc_id      = local.vpc.id

  # private subnet → NAT 인스턴스 허용 (에페멀 포트 범위)
  ingress {
    description = "Private subnet outbound"
    from_port   = 1
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [local.vpc.cidr]
  }

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

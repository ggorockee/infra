resource "aws_security_group" "ssm_endpoint" {
  name        = "SSM-ENDPOINT-SG"
  description = "Allow HTTPS from VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # VPC CIDR로 수정
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "SSM-ENDPOINT-SG"
  }
}

# NAT 없이 private-only 환경에서 EKS가 AWS API/ECR/ST S3 등에 접근하도록 VPC Endpoint 설정


// ─────────────────────────────────────────────────────────────
// VPC Endpoint용 Security Group 생성
// ─────────────────────────────────────────────────────────────

resource "aws_security_group" "vpce" {
  count       = var.create_vpce ? 1 : 0
  name        = "eks-vpce-sg"
  description = "for EKS/VPC endpoints"
  vpc_id      = data.aws_vpc.this.id

  # 내부에서 HTTPS 호출 허용 (EKS/ECR/STS 등)
  ingress {
    description = "Allow HTTPS from private subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  # 외부 통신은 모두 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "EKS-VPCE-SG"
  }
}

resource "aws_vpc_endpoint" "eks_api" {
  count              = var.create_vpce ? 1 : 0
  vpc_id             = data.aws_vpc.this.id
  service_name       = "com.amazonaws.${local.region}.eks"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [aws_security_group.vpce[0].id]
  depends_on         = [aws_security_group.vpce]
  tags = {
    Name = "EKS_API"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  count              = var.create_vpce ? 1 : 0
  vpc_id             = data.aws_vpc.this.id
  service_name       = "com.amazonaws.${local.region}.ecr.api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [aws_security_group.vpce[0].id]
  depends_on         = [aws_vpc_endpoint.eks_api]
  tags = {
    Name = "ECR_API"
  }
}

resource "aws_vpc_endpoint" "ec2" {
  count               = var.create_vpce ? 1 : 0
  vpc_id              = data.aws_vpc.this.id
  service_name        = "com.amazonaws.${local.region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.vpce[0].id]
  private_dns_enabled = true
  depends_on          = [aws_vpc_endpoint.ecr_api]
  tags = {
    Name = "EC2"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count              = var.create_vpce ? 1 : 0
  vpc_id             = data.aws_vpc.this.id
  service_name       = "com.amazonaws.${local.region}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [aws_security_group.vpce[0].id]
  depends_on         = [aws_vpc_endpoint.ec2]
  tags = {
    Name = "ECR_DKR"
  }
}

resource "aws_vpc_endpoint" "sts" {
  count              = var.create_vpce ? 1 : 0
  vpc_id             = data.aws_vpc.this.id
  service_name       = "com.amazonaws.${local.region}.sts"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [aws_security_group.vpce[0].id]
  depends_on         = [aws_vpc_endpoint.ecr_dkr]
  tags = {
    Name = "STS"
  }
}

resource "aws_vpc_endpoint" "s3" {
  count             = var.create_vpce ? 1 : 0
  vpc_id            = data.aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.private_route_table_ids
  depends_on        = [aws_vpc_endpoint.sts]
  tags = {
    Name = "S3"
  }
}

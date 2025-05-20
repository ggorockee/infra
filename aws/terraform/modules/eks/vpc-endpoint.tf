resource "aws_security_group" "eks_vpce_sg" {
  count  = var.using_nat ? 0 : 1
  name   = "eks-vpce-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "Allow AWS API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "eks_api" {
  count              = var.using_nat ? 0 : 1
  vpc_endpoint_type  = "Interface"
  service_name       = "com.amazonaws.${data.aws_region.current.name}.eks"
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.eks_vpce_sg[0].id]
}

resource "aws_vpc_endpoint" "ecr_api" {
  count              = var.using_nat ? 0 : 1
  vpc_endpoint_type  = "Interface"
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.eks_vpce_sg[0].id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count              = var.using_nat ? 0 : 1
  vpc_endpoint_type  = "Interface"
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.eks_vpce_sg[0].id]
}

resource "aws_vpc_endpoint" "sts" {
  count              = var.using_nat ? 0 : 1
  vpc_endpoint_type  = "Interface"
  service_name       = "com.amazonaws.${data.aws_region.current.name}.sts"
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.eks_vpce_sg[0].id]
}

resource "aws_vpc_endpoint" "s3" {
  count             = var.using_nat ? 0 : 1
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_id            = var.vpc_id
  route_table_ids   = local.private_route_table_ids
}

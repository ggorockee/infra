 # NAT 없이 private-only 환경에서 EKS가 AWS API/ECR/ST S3 등에 접근하도록 VPC Endpoint 설정


 // ─────────────────────────────────────────────────────────────
 // VPC Endpoint용 Security Group 생성
 // ─────────────────────────────────────────────────────────────

 resource "aws_security_group" "vpce" {
   count       = var.using_nat ? 0 : 1
   name        = "${var.cluster_name}-vpce-sg"
   description = "for EKS/VPC endpoints"
   vpc_id      = data.aws_vpc.eks.id

   # 내부에서 HTTPS 호출 허용 (EKS/ECR/STS 등)
   ingress {
     description = "Allow HTTPS from private subnets"
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = [data.aws_vpc.eks.cidr_block]
   }

   # 외부 통신은 모두 허용
   egress {
     from_port   = 0
     to_port     = 0
     protocol    = "-1"
     cidr_blocks = ["0.0.0.0/0"]
   }

   tags = {
     "Name" = "${var.cluster_name}-vpce-sg"
   }
 }

 resource "aws_vpc_endpoint" "eks_api" {
   count              = var.using_nat ? 0 : 1
   vpc_id             = var.vpc_id
   service_name       = "com.amazonaws.${local.region}.eks"
   vpc_endpoint_type  = "Interface"
   subnet_ids         = var.subnet_ids
   security_group_ids = [aws_security_group.vpce[0].id]
   depends_on = [aws_security_group.vpce]
 }

 resource "aws_vpc_endpoint" "ecr_api" {
   count              = var.using_nat ? 0 : 1
   vpc_id             = var.vpc_id
   service_name       = "com.amazonaws.${local.region}.ecr.api"
   vpc_endpoint_type  = "Interface"
   subnet_ids         = var.subnet_ids
   security_group_ids = [aws_security_group.vpce[0].id]
   depends_on = [aws_vpc_endpoint.eks_api]
   tags = {
     Name = "ECR_API"
   }
 }

 resource "aws_vpc_endpoint" "ecr_dkr" {
   count              = var.using_nat ? 0 : 1
   vpc_id             = var.vpc_id
   service_name       = "com.amazonaws.${local.region}.ecr.dkr"
   vpc_endpoint_type  = "Interface"
   subnet_ids         = var.subnet_ids
   security_group_ids = [aws_security_group.vpce[0].id]
   depends_on = [aws_vpc_endpoint.ecr_api]
   tags = {
     Name = "ECR_DKR"
   }
 }

 resource "aws_vpc_endpoint" "sts" {
   count              = var.using_nat ? 0 : 1
   vpc_id             = var.vpc_id
   service_name       = "com.amazonaws.${local.region}.sts"
   vpc_endpoint_type  = "Interface"
   subnet_ids         = var.subnet_ids
   security_group_ids = [aws_security_group.vpce[0].id]
   depends_on = [aws_vpc_endpoint.ecr_dkr]
   tags = {
     Name = "STS"
   }
 }

 resource "aws_vpc_endpoint" "s3" {
   count             = var.using_nat ? 0 : 1
   vpc_id            = var.vpc_id
   service_name      = "com.amazonaws.${local.region}.s3"
   vpc_endpoint_type = "Gateway"
   route_table_ids   = local.private_route_table_ids
   depends_on = [aws_vpc_endpoint.sts]
   tags = {
     Name = "S3"
   }
 }

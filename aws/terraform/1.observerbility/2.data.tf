###########################
# VPC
###########################
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["default-vpc"]
  }
}



###########################
# SUBNET
###########################
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  tags = {
    "Tier" = "private"
  }
}


data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  tags = {
    "Tier" = "public"
  }
}

###########################
# INSTANCE PROFILE
###########################
data "aws_iam_instance_profile" "CWSSM" {
  name = var.cloud_watch_ssm_role_name
}

###########################
# Prefix List 
###########################
# 프리픽스 리스트 데이터 소스
data "aws_ec2_managed_prefix_list" "vpn_source" {
  filter {
    name   = "prefix-list-id"
    values = [local.prefix_list_id]
  }
}

###########################
# Route53
###########################
data "aws_route53_zone" "ggorockee" {
  name         = local.hosted_zone_name
  private_zone = false
}


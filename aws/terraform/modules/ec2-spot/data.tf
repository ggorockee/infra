data "aws_region" "current" {}

data "aws_vpc" "current" {
  id = var.vpc_id
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.current.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.current.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

# Fetch the latest Amazon NAT AMI
data "aws_ami" "nat" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat-*"]
  }
  owners = ["amazon"]
}
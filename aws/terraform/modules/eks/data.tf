data "aws_vpc" "current" {
  id = var.vpc_id
}

data "aws_region" "current" {}

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

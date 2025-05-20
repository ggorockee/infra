data "aws_region" "current" {}

data "aws_route_tables" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

# VPC 정보 가져오기
data "aws_vpc" "this" {
  id = data.terraform_remote_state.network.outputs.vpc_id
}

######
# Current Region lookup
######
data "aws_region" "current" {
  # no arguments needed
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}
# data "aws_region" "current" {}

 # VPC 정보 가져오기
 data "aws_vpc" "eks" {
   id = var.vpc_id
 }

######
# Current Region lookup
######
data "aws_region" "current" {
  # no arguments needed
}

######

 # “내부 ELB(private)” 태그가 달린 서브넷만 골라오기
 data "aws_subnets" "private" {
   filter {
     name   = "vpc-id"
     values = [data.aws_vpc.eks.id]
   }
   filter {
     name   = "tag:kubernetes.io/role/internal-elb"
     values = ["1"]
   }
 }

 data "aws_route_tables" "private" {
   filter {
     name   = "vpc-id"
     values = [var.vpc_id]
   }

   filter {
     name   = "tag:Name"
     values = ["arpegezz-private-rt"]
   }
 }

# VPC Setting
module "vpc" {
  source = "../../modules/vpc"
  # vpc_cidr = [ string ]
  # public_subnets = [ string ]
  # azs = [ string ]
  # tags = [ map(string = string) ]
}

module "eks" {
  source = "../../modules/eks"
}

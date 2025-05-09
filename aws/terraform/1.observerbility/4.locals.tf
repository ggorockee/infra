locals {
  sg = {
    name = {
      observerbility = "observerbility"
      alb            = "management-alb-sg"
    }
  }

  ec2 = {
    ami         = "ami-061fdbe1769e05459" # Amazon Linux 2 Kernel 5.10 AMI
    type        = "t3.micro"
    volume_size = 30
    volume_type = "gp3"
  }

  alb = {
    name = "ggorockee-management-alb"
  }

  hosted_zone_name = "ggorockee.com."
  prefix_list_id   = "pl-08274fbab5b49c91c"

  domain_names = [
    var.domain_name,
    "*.${var.domain_name}"
  ]

  common_tags = {
    Managed_By = "Terraform"
  }
}

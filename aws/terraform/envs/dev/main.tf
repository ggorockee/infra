# VPC Setting
module "vpc" {
  source = "../../modules/vpc"
  owner  = "arpegezz"
}

# module "eks" {
#   source = "../../modules/eks"
# }


# data "terraform_remote_state" "network" {
#   backend = "s3"
#   config = {
#     bucket = "arpegez-terraform-state"
#     key    = "dev/terraform.tfstate"
#     region = "ap-northeast-2" # 버킷 리전
#   }
# }

# module "vpn" {
#   source        = "../../modules/ec2"
#   instance_name = "OPENVPN"
#   instance_type = "t3.micro"
#   ami_id        = "ami-09a093fa2e3bfca5a"
#   # subnet_id     = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
#   # vpc_id        = data.terraform_remote_state.network.outputs.vpc_id
#   subnet_id = "subnet-03edab22cdb24a25a"
#   vpc_id    = "vpc-0c660412891b91b4d"
#   sg_name   = "OpenVPN Access Server / Self-Hosted VPN (BYOL)-2.13.1-AutogenByAWSMP"

#   security_group_ingress = {
#     HTTP = {
#       description = "Allow HTTPS"
#       protocol    = "tcp"
#       from_port   = "943"
#       to_port     = "943"
#       cidr_blocks = ["0.0.0.0/0"]
#     }

#     UDP = {
#       description = "Allow UDP"
#       protocol    = "udp"
#       from_port   = "1194"
#       to_port     = "1194"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#   }
# }


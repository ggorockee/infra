# VPC Setting
# module "vpc" {
#   source           = "../../modules/vpc"
#   owner            = "arpegezz"
#   eks_cluster_name = var.eks_cluster_name
# }

# data "terraform_remote_state" "network" {
#   backend = "s3"
#   config = {
#     bucket = "arpegez-terraform-state"
#     key    = "dev/terraform.tfstate"
#     region = "ap-northeast-2" # 버킷 리전
#   }
# }

# module "nat_instance" {
#   source        = "../../modules/ec2-nat"
#   vpc_id        = data.terraform_remote_state.network.outputs.vpc_id
#   use_spot      = true
#   instance_type = "t3.micro"
#   root_block_device = {
#     volume_size           = 20
#     volume_type           = "gp3"
#     delete_on_termination = true
#   }
#   instance_market_options = {
#     market_type                    = "spot"
#     instance_interruption_behavior = "stop"
#     spot_instance_type             = "persistent"
#   }
#   owner = "arpegezz"
# }

# module "vpn_instance" {
#   source        = "../../modules/ec2-spot"
#   vpc_id        = data.terraform_remote_state.network.outputs.vpc_id
#   use_spot      = true
#   instance_type = "t3.micro"
#   using_eip     = true

#   instance_name               = "OPENVPN"
#   ami_name                    = "ami-09a093fa2e3bfca5a"
#   subnet_id                   = local.sorted_public_subnets[0]
#   source_dest_check           = true
#   associate_public_ip_address = false
#   iam_instance_profile        = "CloudWatchSSMRole"


#   root_block_device = {
#     volume_size           = 10
#     volume_type           = "gp3"
#     delete_on_termination = true
#   }
#   instance_market_options = {
#     market_type                    = "spot"
#     instance_interruption_behavior = "stop"
#     spot_instance_type             = "persistent"
#   }
#   security_group_config = {
#     security_group_name = "openvpn-sg"
#     ingress_rule = {
#       HTTP = {
#         description = "Allow HTTP"
#         protocol    = "tcp"
#         from_port   = "943"
#         to_port     = "943"
#         cidr_blocks = ["0.0.0.0/0"]
#       }
#       UDP = {
#         description = "Allow UDP"
#         protocol    = "udp"
#         from_port   = "1194"
#         to_port     = "1194"
#         cidr_blocks = ["0.0.0.0/0"]
#       }
#       Monitoring = {
#         description = "Allow Prometheus"
#         protocol    = "tcp"
#         from_port   = "9100"
#         to_port     = "9100"
#         cidr_blocks = [data.aws_vpc.this.cidr_block]
#       }
#       #      MONITORING = {
#       #        description = "Monitoring"
#       #        protocol    = "-1"
#       #        from_port   = 0
#       #        to_port     = 0
#       #        cidr_blocks = ["0.0.0.0/0"]
#       #      }
#     }
#   }
#   owner = "arpegezz"
# }

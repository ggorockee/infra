# module "bastion" {
#   source        = "../../modules/ec2-spot"
#   vpc_id        = data.terraform_remote_state.network.outputs.vpc_id
#   use_spot      = true
#   instance_type = "t3.small"
#   using_eip     = false

#   instance_name               = "BASTION"
#   ami_name                    = "ami-05377cf8cfef186c2"
#   subnet_id                   = sort(data.terraform_remote_state.network.outputs.private_subnet_ids)[0]
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
#     security_group_name = "bastion-sg"
#     ingress_rule = {
#       ALL = {
#         description = "Allow All Traffic from VPN"
#         protocol    = "-1"
#         from_port   = 0
#         to_port     = 0
#         cidr_blocks = ["10.0.1.154/32"]
#       }

#       Monitoring = {
#         description = "Allow Prometheus"
#         protocol    = "tcp"
#         from_port   = "9100"
#         to_port     = "9100"
#         cidr_blocks = [data.aws_vpc.this.cidr_block]
#       }
#     }
#   }
# }

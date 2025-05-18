module "vpn-test" {
  source               = "../../modules/ec2"
  instance_name        = "OPENVPN"
  instance_type        = "t3.micro"
  ami_id               = "ami-05377cf8cfef186c2"
  subnet_id            = data.terraform_remote_state.network.outputs.private_subnet_ids[0]
  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id
  sg_name              = "NGINX-8080"
  iam_instance_profile = data.aws_iam_role.SSM.name
  root_block_device = {
    volume_type = "gp3"
    volume_size = "8"
  }

  ebs_block_device = {}

  security_group_ingress = {
    HTTP = {
      description = "Allow HTTPS"
      protocol    = "tcp"
      from_port   = "8080"
      to_port     = "8080"
      cidr_blocks = ["10.0.1.16/32"]
    }
  }
}

locals {
  region = data.aws_region.current.name
  vpc = {
    id   = data.aws_vpc.current.id
    cidr = data.aws_vpc.current.cidr_block
  }
  use_spot      = var.use_spot
  instance_type = var.instance_type
  ami_name      = var.ami_name
  subnet_id     = var.subnet_id
  key_pair_name = var.key_pair_name

  root_block_device = {
    volume_size           = var.root_block_device.volume_size
    volume_type           = var.root_block_device.volume_type
    delete_on_termination = var.root_block_device.delete_on_termination
    iops                  = var.root_block_device.iops
    throughput            = var.root_block_device.throughput
  }

  instance_market_options = {
    market_type                    = var.instance_market_options.market_type
    instance_interruption_behavior = var.instance_market_options.instance_interruption_behavior
    spot_instance_type             = var.instance_market_options.spot_instance_type
  }

  owner                 = upper(var.owner)
  security_group_config = var.security_group_config
  source_dest_check     = var.source_dest_check

  using_eip                   = var.using_eip
  instance_name               = var.instance_name
  associate_public_ip_address = var.associate_public_ip_address
  iam_instance_profile        = var.iam_instance_profile != "" ? var.iam_instance_profile : null
}
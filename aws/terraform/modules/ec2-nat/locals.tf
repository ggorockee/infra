locals {
  region = data.aws_region.current.name
  vpc = {
    id   = data.aws_vpc.current.id
    cidr = data.aws_vpc.current.cidr_block
  }
  use_spot      = var.use_spot
  instance_type = var.instance_type
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

  owner = upper(var.owner)
}
# Launch a t3.micro NAT instance, optionally as a Spot Instance
resource "aws_instance" "this" {
  ami                         = local.ami_name
  instance_type               = local.instance_type
  subnet_id                   = local.subnet_id
  associate_public_ip_address = local.associate_public_ip_address
  key_name                    = local.key_pair_name != "" ? local.key_pair_name : null
  iam_instance_profile        = local.iam_instance_profile

  # Disable source/destination checks to allow NAT forwarding
  source_dest_check = local.source_dest_check
  vpc_security_group_ids = length(local.security_group_config) > 0 ? [
    aws_security_group.default[0].id
  ] : []

  root_block_device {
    volume_size           = local.root_block_device.volume_size
    volume_type           = local.root_block_device.volume_type
    delete_on_termination = local.root_block_device.delete_on_termination
    iops                  = local.root_block_device.iops
    throughput            = local.root_block_device.throughput
  }

  # If use_spot is true, configure as a persistent Spot Instance
  dynamic "instance_market_options" {
    for_each = local.use_spot ? [1] : []
    content {
      market_type = local.instance_market_options.market_type
      spot_options {
        # Stop (not terminate) on interruption
        instance_interruption_behavior = local.instance_market_options.instance_interruption_behavior
        spot_instance_type             = local.instance_market_options.spot_instance_type
      }
    }
  }

  tags = {
    Name = upper(local.instance_name)
  }
}

# Allocate a VPC Elastic IP for the NAT instance
resource "aws_eip" "this" {
  count      = local.using_eip ? 1 : 0
  depends_on = [aws_instance.this]
  tags = {
    Name = upper(local.instance_name)
  }
}


# Associate the Elastic IP with the NAT instance
resource "aws_eip_association" "eip" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.0.id
  depends_on    = [aws_eip.this]
}
# Launch a t3.micro NAT instance, optionally as a Spot Instance
resource "aws_instance" "nat" {
  ami                         = data.aws_ami.nat.id
  instance_type               = local.instance_type
  subnet_id                   = data.aws_subnets.public.ids[0]
  associate_public_ip_address = true
  key_name                    = local.key_pair_name != "" ? local.key_pair_name : null

  # Disable source/destination checks to allow NAT forwarding
  source_dest_check = false

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
    Name = "NAT-${local.owner}"
  }
}

# Allocate a VPC Elastic IP for the NAT instance
resource "aws_eip" "nat" {
  depends_on = [aws_instance.nat]
  tags = {
    Name = upper("nat-instance-${local.owner}")
  }
}


# Associate the Elastic IP with the NAT instance
resource "aws_eip_association" "nat" {
  instance_id   = aws_instance.nat.id
  allocation_id = aws_eip.nat.id
  depends_on    = [aws_eip.nat]
}

# Create a new route table for private subnets
resource "aws_route_table" "private_nat" {
  vpc_id     = var.vpc_id
  depends_on = [aws_eip_association.nat]
  tags = {
    Name = upper("rtb-private-nat-${local.owner}")
  }
}

# Add a default route through the NAT instance
resource "aws_route" "priv_subnet_default" {
  route_table_id         = aws_route_table.private_nat.id
  depends_on             = [aws_route_table.private_nat]
  destination_cidr_block = "0.0.0.0/0"
  #  instance_id            = aws_instance.nat.id
  network_interface_id = aws_instance.nat.primary_network_interface_id
}

# Associate each private subnet with the new route table
resource "aws_route_table_association" "private_subnets" {
  for_each       = toset(data.aws_subnets.private.ids)
  depends_on     = [aws_route.priv_subnet_default]
  subnet_id      = each.key
  route_table_id = aws_route_table.private_nat.id
}


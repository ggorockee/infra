resource "aws_security_group" "this" {
  name        = local.sg.name.observerbility
  description = "Allow VPN traffic"
  vpc_id      = data.aws_vpc.selected.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "observerbility"
  }
}

resource "aws_security_group_rule" "this" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.this.id
  prefix_list_ids   = ["pl-08274fbab5b49c91c"]
  description       = "vpn-source"
}

#################################
# ALB
#################################
resource "aws_security_group" "alb" {
  name        = local.sg.name.alb
  description = "Allow HTTP and HTTPS inbound traffic"
  vpc_id      = data.aws_vpc.selected.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.sg.name.alb
  }
}

resource "aws_security_group_rule" "allow_prefix_list" {
  for_each          = toset(["80", "443"])
  depends_on        = [aws_security_group.alb]
  type              = "ingress"
  from_port         = each.key
  to_port           = each.key
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.vpn_source.id]
  description       = "vpn-source"
}

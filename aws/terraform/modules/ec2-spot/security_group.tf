resource "aws_security_group" "default" {
  count       = length(var.security_group_config) > 0 ? 1 : 0
  name        = upper(var.security_group_config.security_group_name)
  description = "Allow traffic"
  vpc_id      = local.vpc.id

  # NAT → 인터넷 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = upper(var.security_group_config.security_group_name)
  }
}

resource "aws_security_group_rule" "allow_all_ingress" {
  for_each = {
    for k, v in var.security_group_config.ingress_rule : k => v
  }
  type              = "ingress" # ingress / egress
  description       = each.value.description
  security_group_id = aws_security_group.default[0].id
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_blocks       = each.value.cidr_blocks
}
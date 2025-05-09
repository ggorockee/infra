resource "aws_lb" "lb" {
  name               = local.alb.name
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.private.ids

  tags = {
    Environment = "dev"
    Name        = local.alb.name
  }
}

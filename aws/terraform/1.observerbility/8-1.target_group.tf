resource "aws_lb_target_group" "monitoring_tg" {
  name     = "monitoring-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    port                = 3000
  }


  tags = merge(local.common_tags)
}

# =================================================
# Target Group에 EC2 인스턴스 등록
# =================================================
resource "aws_lb_target_group_attachment" "my_attachments" {
  for_each         = { for idx, instance in aws_instance.linux-server : idx => instance.id }
  target_group_arn = aws_lb_target_group.monitoring_tg.arn
  target_id        = aws_instance.linux-server[0].id
  port             = 3000
}

# ===========================================================
# OPENVPN
# ===========================================================


resource "aws_lb_target_group" "openvpn" {
  name     = "openvpn-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    port                = 80
  }


  tags = merge(local.common_tags)
}

# =================================================
# Target Group에 EC2 인스턴스 등록
# =================================================
resource "aws_lb_target_group_attachment" "openvpn" {
  target_group_arn = aws_lb_target_group.openvpn.arn
  target_id        = "i-03b4e8aa81cec9079"
  port             = 80
}


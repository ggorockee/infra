
# =================================================
# ALB Listener
# =================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.monitoring_tg.arn
  }

  tags = local.common_tags
}


## add rule
resource "aws_lb_listener_rule" "openvpn_host_rule" {
  listener_arn = aws_lb_listener.https.arn # HTTPS(443) 리스너 ARN을 참조
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openvpn.arn # openvpn-tg 타겟 그룹 ARN
  }

  condition {
    host_header {
      values = ["openvpn.${var.domain_name}"]
    }
  }

  tags = merge(local.common_tags, {
    "Name" : "OpenVPN"
  })
}

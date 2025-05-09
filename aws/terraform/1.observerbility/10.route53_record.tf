
resource "aws_route53_record" "alb_alias" {
  zone_id = data.aws_route53_zone.ggorockee.zone_id
  name    = "monitor" # 예: app.ggorockee.com
  type    = "A"

  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}

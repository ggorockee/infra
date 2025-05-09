output "management_alb_dns_name" {
  value = aws_lb.lb.dns_name
}

output "r53_zone_id" {
  value = data.aws_route53_zone.ggorockee.zone_id
}

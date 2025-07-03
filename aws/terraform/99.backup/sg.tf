# security group
data "aws_security_group" "nginx" {
  name = "NGINX"
}

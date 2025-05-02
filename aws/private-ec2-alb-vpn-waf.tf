# #########################################
# # 보안그룹
# #########################################
# resource "aws_security_group" "alb-sg" {
#   name        = "alb-sg"
#   description = "Allow HTTP and SSH inbound traffic"
#   vpc_id      = data.aws_vpc.selected.id

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "web-server-sg"
#   }
# }

# resource "aws_security_group_rule" "allow_prefix_list" {
#     depends_on = [ aws_security_group.alb-sg ]
#   type = "ingress"
#   from_port = 80
#   to_port = 80
#   protocol = "tcp"
#   security_group_id = aws_security_group.alb-sg.id
#   prefix_list_ids = ["pl-08274fbab5b49c91c"]
#   description = "vpn-source"
# }


# resource "aws_security_group" "ec2-sg" {
#     depends_on = [ aws_security_group_rule.allow_prefix_list ]
#   name        = "ec2-sg"
#   description = "Allow HTTP and SSH inbound traffic"
#   vpc_id      = data.aws_vpc.selected.id

#   ingress {
#     description = "Allow HTTP"
#     from_port   = 8080
#     to_port     = 8080
#     protocol    = "tcp"
#     security_groups = [aws_security_group.alb-sg.id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "web-server-sg"
#   }
# }



# #########################################
# # EC2
# #########################################
# resource "aws_instance" "linux-server" {
#   count                       = 2
#   ami                         = "ami-061fdbe1769e05459" # Amazon Linux 2 Kernel 5.10 AMI
#   instance_type               = "t3.micro"
#   subnet_id                   = data.aws_subnets.private.ids[0]
#   vpc_security_group_ids      = [aws_security_group.ec2-sg.id]
#   iam_instance_profile        = data.aws_iam_instance_profile.CWSSM.name
#   key_name                    = ""
#   associate_public_ip_address = false // public일때

#   root_block_device {
#     volume_size = 8
#     volume_type = "gp2"
#   }

#   # lifecycle {
#   #   ignore_changes = [associate_public_ip_address]
#   # }

#   user_data = <<-EOF
# #!/bin/bash
# INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
# # REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')
# # aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value="nginx-$INSTANCE_ID" --region $REGION

# yum update -y
# yum install -y docker
# systemctl start docker
# systemctl enable docker
# echo "<h1>$(hostname)</h1>" > index.html
# docker run -d --name nginx -p "8080:80" -v "$PWD/index.html:/usr/share/nginx/html/index.html" nginx

# # CloudWatch Agent 설치
# yum install -y curl unzip
# curl -O https://amazoncloudwatch-agent.s3.amazonaws.com/centos/amd64/latest/amazon-cloudwatch-agent.rpm
# rpm -U ./amazon-cloudwatch-agent.rpm

# # CloudWatch Agent 설정 적용
# /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
#   -a fetch-config -m ec2 -c ssm:/alarm/AmazonCloudWatch-CustomMetric -s
#   EOF

#   tags = merge(
#     {
#       Name = "EC2-Linux-${count.index + 1}"
#     },
#     {
#       Environment = "dev"
#       Role        = "nginx-server"
#     },
#   )
# }


# #########################################
# # ALB
# #########################################

# # =================================================
# # TargetGroup
# # =================================================
# resource "aws_lb_target_group" "my_tg" {
#   name     = "alb-tg"
#   port     = 8080
#   protocol = "HTTP"
#   vpc_id   = data.aws_vpc.selected.id

#   health_check {
#     path                = "/"
#     protocol            = "HTTP"
#     matcher             = "200-399"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     port = 8080
#   }

#   tags = {
#     Environment = "dev"
#   }
# }

# # =================================================
# # Target Group에 EC2 인스턴스 등록
# # =================================================
# resource "aws_lb_target_group_attachment" "my_attachments" {
#   depends_on = [aws_lb_target_group.my_tg]
#   for_each   = { for idx, instance in aws_instance.linux-server : idx => instance.id }

#   target_group_arn = aws_lb_target_group.my_tg.arn
#   target_id        = each.value
#   port             = 8080
# }



# # =================================================
# # ALB
# # =================================================
# resource "aws_lb" "lb" {
#   depends_on         = [aws_lb_target_group.my_tg, aws_instance.linux-server]
#   name               = "my-alb"
#   load_balancer_type = "application"
#   internal           = true
#   security_groups    = [aws_security_group.alb-sg.id]
#   subnets            = data.aws_subnets.private.ids

#   tags = {
#     Environment = "dev"
#     Name        = "my-alb"
#   }
# }


# # =================================================
# # ALB Listener
# # =================================================
# resource "aws_lb_listener" "my_alb_listener" {
#   depends_on        = [aws_lb.lb]
#   load_balancer_arn = aws_lb.lb.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.my_tg.arn
#   }
# }

# ####
# # 1. WAFv2 Web ACL 생성
# # WAF 웹 ACL 생성
# resource "aws_wafv2_web_acl" "this" {
#   name        = "my-private-alb-waf"
#   description = "WAF for private ALB with logging enabled"
#   scope       = "REGIONAL"

#   default_action {
#     allow {}
#   }

#   # CloudWatch 로그에 로깅 설정
#   visibility_config {
#     cloudwatch_metrics_enabled = true
#     metric_name                = "my-private-alb-waf"
#     sampled_requests_enabled   = true
#   }

#   # AWS 관리형 룰 추가 (AWSManagedRulesCommonRuleSet)
#   rule {
#     name     = "AWS-AWSManagedRulesCommonRuleSet"
#     priority = 1

#     override_action {
#       none {}
#     }

#     statement {
#       managed_rule_group_statement {
#         name        = "AWSManagedRulesCommonRuleSet"
#         vendor_name = "AWS"
#       }
#     }

#     visibility_config {
#       sampled_requests_enabled   = true
#       cloudwatch_metrics_enabled = true
#       metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
#     }
#   }

#   tags = {
#     Name        = "my-private-alb-waf"
#     Environment = "dev"
#   }
# }



# # 2. WAF와 ALB 연결
# resource "aws_wafv2_web_acl_association" "this" {
#   resource_arn = aws_lb.lb.arn
#   web_acl_arn  = aws_wafv2_web_acl.this.arn
# }

# # WAF 로그를 저장할 CloudWatch 로그 그룹 생성
# resource "aws_cloudwatch_log_group" "waf_logs" {
#   name              = "aws-waf-logs-hahahaha"
#   retention_in_days = 30
  
#   tags = {
#     Name        = "WAF-Logs"
#     Environment = "dev"
#   }
# }

# resource "aws_wafv2_web_acl_logging_configuration" "this" {
#   log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
#   resource_arn           = aws_wafv2_web_acl.this.arn
  
#   # 필요 시 민감한 필드 제외
#   # redacted_fields {
#   #   single_header {
#   #     name = "authorization"
#   #   }
#   # }
# }
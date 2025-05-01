## =================================================
## 인스턴스 세팅
## =================================================

# resource "aws_instance" "linux-server" {
#   count                  = 3
#   ami                    = "ami-061fdbe1769e05459" # Amazon Linux 2 Kernel 5.10 AMI
#   instance_type          = "t3.micro"
#   subnet_id              = data.aws_subnets.private.ids.0
#   vpc_security_group_ids = [aws_security_group.web_server_sg.id]
#   iam_instance_profile   = data.aws_iam_instance_profile.CWSSM.name
#   key_name               = ""
#   # associate_public_ip_address = true // public일때

#   root_block_device {
#     volume_size = 8
#     volume_type = "gp2"
#   }

#   # lifecycle {
#   #   ignore_changes = [associate_public_ip_address]
#   # }

#   user_data = <<-EOF
#     #!/bin/bash
#     INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
#     # REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')
#     # aws ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value="nginx-$INSTANCE_ID" --region $REGION

#     yum update -y
#     yum install -y docker
#     systemctl start docker
#     systemctl enable docker
#     echo "<h1>$(hostname)</h1>" > index.html
#     docker run -d --name nginx -p "8080:80" -v "$PWD/index.html:/usr/share/nginx/html/index.html" nginx

#     # CloudWatch Agent 설치
#     yum install -y curl unzip
#     curl -O https://amazoncloudwatch-agent.s3.amazonaws.com/centos/amd64/latest/amazon-cloudwatch-agent.rpm
#     rpm -U ./amazon-cloudwatch-agent.rpm

#     # CloudWatch Agent 설정 적용
#     /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
#       -a fetch-config -m ec2 -c ssm:/alarm/AmazonCloudWatch-CustomMetric -s
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


## =================================================
## 보안 그룹
## =================================================

locals {
  sg = {
    name = "web-server-sg"
  }

  tg = {
    name     = "ggorockee-alb-tg"
    protocol = "HTTP"
  }

  lb = {
    name               = "ggorockee-alb"
    load_balancer_type = "application"
  }
}



# resource "aws_security_group" "web_server_sg" {
#   name        = local.sg.name
#   description = "Allow HTTP"
#   vpc_id      = data.aws_vpc.selected.id

#   ingress {
#     description = "Allow HTTP"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "Allow Docker HTTP"
#     from_port   = 8080
#     to_port     = 8080
#     protocol    = "tcp"
#     self        = true
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = local.sg.name
#   }
# }



## =================================================
## TargetGroup
## =================================================
# resource "aws_lb_target_group" "my_tg" {
#   name     = local.tg.name
#   port     = 8080
#   protocol = local.tg.protocol
#   vpc_id   = data.aws_vpc.selected.id

#   health_check {
#     path                = "/"
#     protocol            = "HTTP"
#     matcher             = "200-399"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }

#   tags = {
#     Environment = "dev"
#   }
# }

## =================================================
## Target Group에 EC2 인스턴스 등록
## =================================================
# resource "aws_lb_target_group_attachment" "my_attachments" {
#   depends_on = [aws_lb_target_group.my_tg]
#   for_each   = { for idx, instance in aws_instance.linux-server : idx => instance.id }

#   target_group_arn = aws_lb_target_group.my_tg.arn
#   target_id        = each.value
#   port             = 8080
# }



## =================================================
## ALB
## =================================================
# resource "aws_lb" "lb" {
#   depends_on         = [aws_lb_target_group.my_tg]
#   name               = local.lb.name
#   load_balancer_type = local.lb.load_balancer_type
#   internal           = false
#   security_groups    = [aws_security_group.web_server_sg.id]
#   subnets            = data.aws_subnets.public.ids

#   tags = {
#     Environment = "dev"
#     Name        = local.lb.name
#   }
# }


## =================================================
## ALB Listener
## =================================================
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

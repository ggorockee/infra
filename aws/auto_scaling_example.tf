# 시작 템플릿 생성
# 이름: EC2_ASG
# 템플릿버전: V1
# ami                    = "ami-061fdbe1769e05459" # Amazon Linux 2 Kernel 5.10 AMI
# instance_type          = "t3.micro"
# 보안그룹: SG_ASG

# AutoScaling 그룹 생성
# 시작템플릿 위에서 만든거:
# 버전은 : latest
# 로드밸런서 없음
# VPC Lattice 통합옵션 없음
# CloudWatch 내에서 그룹 지표 수집 활성화
# 원하는 용량 2
# 최소1
# 최대5
# 크기조정정책없음
# 인스턴스유지관리정책: 정책없음
# 인스턴스 축소 보호 활성화 off
# 알림추가 없음
# Tag는 추천해줘 

locals {
  launch_template_name = "EC2_ASG"
  ami_id               = "ami-061fdbe1769e05459" # Amazon Linux 2 Kernel 5.10 AMI
  instance_type        = "t3.micro"

  # ASG 설정
  asg_name             = "EC2-ASG"
  asg_min_size         = 1
  asg_max_size         = 5
  asg_desired_capacity = 2

  common_tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Project     = "ASG-Demo"
    Service     = "EC2-AutoScaling"
    CreatedDate = "2025-05-02"
  }
}


################################################################################
#                              Security Group                                  #
#                                                                              #
#   - ASG에서 사용하기 위한 보안그룹                                                  #
#                                                                              #
################################################################################
# resource "aws_security_group" "sg_asg" {
#   name        = "SG_ASG"
#   description = "Security group for Auto Scaling Group"
#   vpc_id      = data.aws_vpc.selected.id

#   ingress {
#     description = "Allow HTTP"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "Allow SSH"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "SG_ASG"
#   }
# }


################################################################################
#                              Launch Template                                 #
#                                                                              #
#   - EC2 시작 템플릿 리소스                                                        #
#   - Auto Scaling, EC2 배포 등에 활용                                             #
################################################################################
# resource "aws_launch_template" "ec2_launch_template" {
#   name        = local.launch_template_name
#   description = "시작 템플릿 for ASG"

#   image_id      = local.ami_id
#   instance_type = local.instance_type
#   iam_instance_profile {
#     name = data.aws_iam_instance_profile.CWSSM.name
#   }
#   user_data = base64encode(<<-EOF
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
#   )

#   vpc_security_group_ids = [aws_security_group.sg_asg.id]

#   # 인스턴스에 태그 지정
#   tag_specifications {
#     resource_type = "instance"
#     tags = merge(
#       local.common_tags,
#       {
#         Name = "${local.asg_name}-Instance"
#       }
#     )
#   }

#   # 볼륨에 태그 지정
#   tag_specifications {
#     resource_type = "volume"
#     tags = merge(
#       local.common_tags,
#       {
#         Name = "${local.asg_name}-Volume"
#       }
#     )
#   }

#   # 시작 템플릿 자체에 태그 지정
#   tags = merge(
#     local.common_tags,
#     {
#       Name    = local.launch_template_name
#       Version = "V1"
#     }
#   )
# }


################################################################################
#                              Auto Scaling Group                              #
#                                                                              #
#   - CloudWatch On                                                            #
################################################################################
# resource "aws_autoscaling_group" "ec2_asg" {
#   name = local.asg_name

#   min_size         = local.asg_min_size
#   max_size         = local.asg_max_size
#   desired_capacity = local.asg_desired_capacity

#   # 최신 시작 템플릿 버전 사용
#   launch_template {
#     id      = aws_launch_template.ec2_launch_template.id
#     version = "$Latest"
#   }

#   vpc_zone_identifier = data.aws_subnets.private.ids

#   # CloudWatch 그룹 지표 활성화
#   metrics_granularity = "1Minute"
#   enabled_metrics = [
#     "GroupMinSize",
#     "GroupMaxSize",
#     "GroupDesiredCapacity",
#     "GroupInServiceInstances",
#     "GroupPendingInstances",
#     "GroupStandbyInstances",
#     "GroupTerminatingInstances",
#     "GroupTotalInstances"
#   ]

#   # 인스턴스 보호 비활성화 (요구사항에 맞춤)
#   protect_from_scale_in = false

#   # ASG 태그 설정 및 인스턴스에 전파
#   dynamic "tag" {
#     for_each = merge(
#       local.common_tags,
#       {
#         Name = local.asg_name
#       }
#     )
#     content {
#       key                 = tag.key
#       value               = tag.value
#       propagate_at_launch = true
#     }
#   }
# }


################################################################################
#                         asg에서 동적 크기 조정 정책 생성                            #
#                                                                              #
#  
#    정책 유형
#      * 대상 추적 크기 조정
#    크기 조정 정책 이름: Target Tracking Policy
#    지표 유형: 평균 CPU 사용률
#    인스턴스 워밍업: 100초                                                           #
# resource "aws_autoscaling_policy" "target_tracking_policy" {
#   name                   = "Target Tracking Policy"
#   policy_type            = "TargetTrackingScaling"
#   autoscaling_group_name = aws_autoscaling_group.ec2_asg.name

#   target_tracking_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ASGAverageCPUUtilization"
#     }
#     target_value = 50.0
#   }

#   estimated_instance_warmup = 100
# }

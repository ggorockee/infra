






# instance profile

# resource "aws_instance" "nginx" {
#   count                  = 0
#   ami                    = "ami-061fdbe1769e05459" # Amazon Linux 2 Kernel 5.10 AMI
#   instance_type          = "t3.micro"
#   subnet_id              = data.aws_subnets.private.ids[0]
#   vpc_security_group_ids = [data.aws_security_group.nginx.id]
#   iam_instance_profile   = data.aws_iam_instance_profile.CWSSM.name

#   root_block_device {
#     volume_size = 8
#     volume_type = "gp2"
#   }

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
#       Name = "nginx-${count.index}"
#     },
#     {
#       Environment = "dev"
#       Role        = "nginx-server"
#     },
#   )
# }

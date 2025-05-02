# resource "aws_iam_role" "CloudWatchSSMRole" {
#   name = var.cloud_watch_ssm_role_name

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# data "aws_iam_policy" "ssm" {
#   arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# data "aws_iam_policy" "cloudwatch" {
#   arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
# }

# locals {
#   policy_arns = [
#     data.aws_iam_policy.cloudwatch.arn,
#     data.aws_iam_policy.ssm.arn
#   ]
# }

# resource "aws_iam_role_policy_attachment" "ssm_attachments" {
#   depends_on = [aws_iam_role.CloudWatchSSMRole]
#   for_each   = toset(local.policy_arns)
#   role       = aws_iam_role.CloudWatchSSMRole.name
#   policy_arn = each.key
# }


# resource "aws_iam_instance_profile" "CloudWatchSSMRole" {
#   name = var.cloud_watch_ssm_role_name
#   role = aws_iam_role.CloudWatchSSMRole.name
# }

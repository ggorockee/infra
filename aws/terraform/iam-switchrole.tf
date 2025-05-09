# resource "aws_iam_role" "EC2_Full_Access_Role" {
#   name = "EC2_Full_Access_Role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::329599650491:user/test"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# data "aws_iam_policy" "ec2_full_access_policy" {
#   arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
# }

# resource "aws_iam_role_policy_attachment" "ec2_full_access_role_attachment" {
#   role       = aws_iam_role.EC2_Full_Access_Role.name
#   policy_arn = data.aws_iam_policy.ec2_full_access_policy.arn
# }


# # 정책 생성
# resource "aws_iam_policy" "EC2_IAM_Role_Policy" {
#   name        = "EC2_IAM_Role_Policy"
#   path        = "/"
#   description = ""

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid      = "VisualEditor0"
#         Effect   = "Allow"
#         Action   = "sts:*"
#         Resource = "${aws_iam_role.EC2_Full_Access_Role.arn}"
#       }
#     ]
#     }
#   )
# }


# data "aws_iam_user" "test" {
#   user_name = "test"
# }

# resource "aws_iam_user_policy_attachment" "ec2_full_access_role_attachment" {
#   user       = data.aws_iam_user.test.user_name
#   policy_arn = aws_iam_policy.EC2_IAM_Role_Policy.arn
# }

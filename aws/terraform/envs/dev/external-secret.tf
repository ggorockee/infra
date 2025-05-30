data "aws_iam_openid_connect_provider" "eks" {
  url = module.eks.eks_cluster_oidc_issuer_url
}

# data "aws_iam_policy_document" "es_assume" {
#   statement {
#     effect  = "Allow"
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     principals {
#       type        = "Federated"
#       identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
#     }
#     condition {
#       test     = "StringEquals"
#       variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
#       values   = ["system:serviceaccount:external-secrets:external-secrets-sa"]
#     }
#   }
# }

# resource "aws_iam_role" "external_secrets" {
#   name               = "eks-external-secrets-role"
#   assume_role_policy = data.aws_iam_policy_document.es_assume.json
# }

# resource "aws_iam_policy" "external_secrets_policy" {
#   name = "external-secrets-policy"
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "secretsmanager:GetSecretValue",
#           "secretsmanager:DescribeSecret",
#           "ssm:GetParameter",
#           "ssm:GetParameters",
#           "ssm:GetParametersByPath"
#         ]
#         Resource = "*" # 필요시 ARN 필터링
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "es_attach" {
#   role       = aws_iam_role.external_secrets.name
#   policy_arn = aws_iam_policy.external_secrets_policy.arn
# }




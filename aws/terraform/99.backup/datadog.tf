resource "aws_iam_policy" "DatadogIntegrationPolicy" {
  name        = "DatadogIntegrationPolicy"
  path        = "/"
  description = ""

  policy = file("${path.module}/datadog.integration.json")
}

resource "aws_iam_policy" "datadog_cloudformation_gettemplatesummary" {
  name        = "DatadogCloudFormationGetTemplateSummary"
  description = "Allow datadog user to call cloudformation:GetTemplateSummary"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "cloudformation:GetTemplateSummary"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "iam_list_roles_policy" {
  name        = "IAMListRolesPolicy"
  description = "Allow listing IAM roles"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "iam:ListRoles",
        Resource = "*"
      }
    ]
  })
}

# 1. IAM Policy 생성
resource "aws_iam_policy" "datadog_cloudformation_create" {
  name        = "DatadogCloudFormationCreateStack"
  description = "Allow CreateStack on DatadogIntegration stack"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "cloudformation:CreateStack",
        Resource = "arn:aws:cloudformation:ap-northeast-2:329599650491:stack/DatadogIntegration/*"
      }
    ]
  })
}



# resource "aws_iam_user_policy_attachment" "attach_list_roles_policy" {
#   user       = "datadog" # 실제 사용자 이름으로 변경하세요
#   policy_arn = aws_iam_policy.iam_list_roles_policy.arn
# }

# 1. SSO-Admin 역할 생성
resource "aws_iam_role" "sso_admin" {
  for_each = {
    for key, entry in var.iam_access_entries : key => entry
    if key == "SSO" && lenth(entry.arns) > 0
  }
  name = "SSO-Admin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        AWS = entry.arns
      }, # 최종 사용자
      Action = "sts:AssumeRole"
    }]
  })
}

# 2. DevOpsAdmin 역할 생성 (SSO-Admin 참조)
resource "aws_iam_role" "devops_admin" {
  count = length(aws_iam_role.sso_admin) > 0 ? 1 : 0
  name  = "DevOpsAdmin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        AWS = one(values(aws_iam_role.sso_admin)[*].arn)
      }, # SSO-Admin ARN 사용
      Action = "sts:AssumeRole"
    }]
  })
  depends_on = [aws_iam_role.sso_admin]
}

resource "aws_iam_role_policy_attachment" "eks_admin" {
  for_each = {
    for i, policy in var.additional_eks_managed_policyment
    : tostring(i) => policy
    if length(aws_iam_role.devops_admin) > 0
  }
  role       = aws_iam_role.devops_admin[0].name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}

# resource "aws_iam_role_policy_attachment" "this" {
#   for_each = local.access_entries

#   role       = each.value.principal_arn
#   policy_arn = each.value.policy_associations["eks-admin"].policy_arn
# }

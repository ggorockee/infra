# 1. SSO-Admin 역할 생성
resource "aws_iam_role" "sso_admin" {
  name = "SSO-Admin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { AWS = "arn:aws:iam::329599650491:user/ggorockee_saa_03" }, # 최종 사용자
      Action    = "sts:AssumeRole"
    }]
  })
}

# 2. DevOpsAdmin 역할 생성 (SSO-Admin 참조)
resource "aws_iam_role" "devops_admin" {
  name = "DevOpsAdmin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { AWS = aws_iam_role.sso_admin.arn }, # SSO-Admin ARN 사용
      Action    = "sts:AssumeRole"
    }]
  })
  depends_on = [aws_iam_role.sso_admin]
}

resource "aws_iam_role_policy_attachment" "eks_admin" {
  role       = aws_iam_role.devops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = local.access_entries

  role       = each.value.principal_arn
  policy_arn = each.value.policy_associations["eks-admin"].policy_arn
}

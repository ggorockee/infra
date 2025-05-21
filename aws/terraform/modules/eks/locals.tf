locals {
  # API 엔드포인트 접근 제어
  cluster_endpoint_private_access = var.cluster_endpoint_private_access # true
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access # false

    # aws-auth ConfigMap 자동 관리 해제 (AssumeRole 방식)
  manage_aws_auth = var.manage_aws_auth # false

    # IRSA/OIDC 사용
  enable_irsa            = var.enable_irsa # true

  # CloudWatch Logs 비활성화
  create_cloudwatch_log_group = var.create_cloudwatch_log_group # false

  access_entries = {
    cluster_assume_role = {
    principal_arn = aws_iam_role.eks_cluster.arn
    type          = "AWS_IAM_ROLE"
  }
  }
}
// ─────────────────────────────────────────────────────────────
// EKS 클러스터용 IAM Role 생성
// ─────────────────────────────────────────────────────────────

# 1) AssumeRole 정책 문서

data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# IAM Role 생성
resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json

  tags = {
    "Name" = "${var.cluster_name}-cluster-role"
  }
}

# 3) 필요한 AWS 관리형 정책 연결
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  for_each = {
    for key, value in var.cluster_policies : key => value
  }
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}
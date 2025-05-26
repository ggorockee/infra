data "aws_vpc" "current" {
  id = var.vpc_id
}

data "aws_region" "current" {}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.current.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

# ────────── 1. 사전: IAM 역할 정의 ──────────
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
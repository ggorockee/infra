data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_node_group_role" {
  name               = upper("${local.cluster_name}-eks-managed-node-group-role")
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
}

resource "aws_iam_role_policy_attachment" "node_group" {
  for_each   = toset(local.node_group_policies)
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = each.value
}
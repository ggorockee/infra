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

data "aws_iam_policy_document" "eks_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = upper("${local.cluster_name}-cluster-role")
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policies" {
  for_each   = toset(local.eks_cluster_policies)
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "eks_addons" {
  statement {
    effect = "Allow"
    actions = [
      "eks:CreateAddon",
      "eks:DeleteAddon",
      "eks:DescribeAddon",
      "eks:DescribeAddonVersions",
      "eks:ListAddons",
      "eks:UpdateAddon",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_addons" {
  name        = "eks-addons-policy"
  description = "Allow EKS cluster to manage Add-Ons"
  policy      = data.aws_iam_policy_document.eks_addons.json
}


resource "aws_iam_role_policy_attachment" "eks_cluster_addons" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = aws_iam_policy.eks_addons.arn
}
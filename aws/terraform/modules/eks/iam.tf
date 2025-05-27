resource "aws_iam_policy" "node_additional" {
  name        = "${local.cluster_name}-node-additional"
  description = "Example usage of node additional policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "default_node_policies" {
  for_each = toset(local.attachment_map)


  role       = each.value.role_name
  policy_arn = "arn:aws:iam::aws:policy/${each.value.policy}"
}
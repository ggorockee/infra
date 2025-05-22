module "ebs_csi_irsa_role" {
  for_each = {
    for k, v in var.var.ebs_csi_irsa_roles : k => v
  }
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  version = "5.55.0"

  create_role = each.value.create_role
  role_name   = each.value.role_name


  provider_url = replace(
    module.eks.cluster_oidc_issuer_url,
    "https://",
    ""
  )

  role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]

  number_of_role_policy_arns = length(
    [
      "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    ]
  )

  oidc_fully_qualified_subjects = each.value.oidc_fully_qualified_subjects
}
module "ebs_csi_irsa_role" {
  for_each = { for k, v in var.ebs_csi_irsa_role : k => v }
  source   = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version  = each.v.terraform_version
}
#resource "aws_iam_role" "eks_cluster" {
#  name               = local.cluster_role_name
#  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
#}
#
#resource "aws_iam_role" "eks_node" {
#  name               = local.node_group_role_name
#  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
#}
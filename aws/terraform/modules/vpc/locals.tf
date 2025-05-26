locals {
  private_subnet_ids = aws_subnet.private[*].id
  cluster_subnets    = var.eks_cluster_name != "" ? toset(local.private_subnet_ids) : null
}
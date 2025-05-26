locals {
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  tags            = merge({}, var.tags)
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
}

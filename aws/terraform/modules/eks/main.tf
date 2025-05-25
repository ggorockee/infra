module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  version      = "20.36.0"
  cluster_name = local.cluster_name

  cluster_endpoint_public_access  = local.cluster_endpoint_public_access
  cluster_endpoint_private_access = local.cluster_endpoint_private_access

  vpc_id     = local.vpc_id
  subnet_ids = local.subnet_ids

  tags        = local.tags
  enable_irsa = local.enable_irsa # false

  cluster_addons = local.cluster_addons
}


// 프라이빗 서브넷 태그
resource "aws_ec2_tag" "private_subnet_tag" {
  for_each    = toset(var.subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_subnet_cluster_tag" {
  for_each    = toset(var.subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "owned"
}

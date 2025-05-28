resource "aws_security_group_rule" "allow_eks_api_from_my_ip" {
  description = "Allow EKS API server access from OPENVPN"
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"

  # Cluster security group
  security_group_id = module.eks.cluster_security_group_id

  # 허용하려는 소스 CIDR
  cidr_blocks = ["10.0.1.154/32"]
}

resource "aws_security_group_rule" "allow_traffic_from_vpn" {
  for_each    = module.eks_managed_node_group
  description = "Allow EKS API server access from OPENVPN"
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"

  # Cluster security group
  security_group_id = each.value.security_group_id

  # 허용하려는 소스 CIDR
  cidr_blocks = ["10.0.1.154/32"]
}

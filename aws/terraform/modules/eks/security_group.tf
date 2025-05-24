resource "aws_security_group_rule" "allow_nodes_to_cp" {
  from_port         = 443
  protocol          = "tcp"
  security_group_id = module.eks.cluster_security_group_id
  source_security_group_id = module.eks.node_security_group_id
  to_port           = 443
  type              = "ingress"
}
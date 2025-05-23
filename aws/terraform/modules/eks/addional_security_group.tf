# resource "aws_security_group" "access" {
#   for_each = {
#     for k, v in var.additional_security_groups : k => v
#   }
#   name   = each.value.name
#   vpc_id = each.value.vpc_id

#   ingress {
#     description = each.value.ingress.description
#     from_port   = each.value.ingress.from_port
#     to_port     = each.value.ingress.to_port
#     protocol    = each.value.ingress.protocol
#     cidr_blocks = each.value.ingress.cidr_blocks
#     # SG-to-SG 통신은 따로 aws_security_group_rule 로 추가
#   }

#   egress {
#     from_port   = each.value.egress.from_port
#     to_port     = each.value.egress.to_port
#     protocol    = each.value.egress.protocol
#     cidr_blocks = each.value.egress.cidr_blocks
#   }

#   tags = each.value.tags
# }

# resource "aws_security_group_rule" "allow_eks_api" {
#   for_each                 = aws_security_group.access
#   depends_on               = [aws_security_group.access]
#   type                     = "ingress"
#   from_port                = 443
#   to_port                  = 443
#   protocol                 = "tcp"
#   security_group_id        = module.eks.cluster_security_group_id
#   source_security_group_id = aws_security_group.access[each.key].id
#   description              = "Allow EKS API access from ${each.key}"
# }
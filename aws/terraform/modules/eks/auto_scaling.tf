resource "aws_autoscaling_group" "self_node" {
  for_each = var.auto_scaling_config

  name             = each.value.name
  desired_capacity = each.value.desired_capacity
  min_size         = each.value.min_size
  max_size         = each.value.max_size

  launch_template {
    id      = aws_launch_template.self_node[each.key].id
    version = "$Latest"
  }

  vpc_zone_identifier = each.value.subnet_ids
  tag {
    key                 = "Name"
    value               = each.value.name
    propagate_at_launch = true
  }
  tag {
    key                 = "kubernetes.io/cluster/${module.eks.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

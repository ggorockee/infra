output "instance_id" {
  value = aws_instance.this.id
}

output "security_group_id" {
  value = local.final_sg_id
}

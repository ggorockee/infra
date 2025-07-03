resource "aws_eip" "this" {
  tags = var.tags
}

resource "aws_eip_association" "this" {
  instance_id   = var.instance_id
  allocation_id = aws_eip.this.id
}

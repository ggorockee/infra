variable "instance_id" {
  description = "EIP를 연결할 EC2 인스턴스 ID"
  type        = string
}

variable "tags" {
  description = "EIP에 적용할 태그"
  type        = map(string)
  default     = {}
}

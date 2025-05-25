variable "eks_cluster_name" {
  type    = string
  default = "dev-eks-cluster"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "arpegezz"
}

variable "OPENVPN_IP" {
  type    = string
  default = "10.0.1.16"
}

variable "create_vpce" {
  type    = bool
  default = false
}
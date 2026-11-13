variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (prod, dev, staging)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the exporter"
  type        = string
  default     = "monitoring"
}

variable "kubernetes_service_account" {
  description = "Kubernetes ServiceAccount name used by prometheus-stackdriver-exporter (Helm release name)"
  type        = string
  default     = "prometheus-stackdriver-exporter"
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast3"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for External Secrets Operator"
  type        = string
  default     = "external-secrets-system"
}

variable "service_account_name" {
  description = "Kubernetes Service Account name for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "helm_chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.9.11"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "cluster_location" {
  description = "GKE cluster location (region)"
  type        = string
}

variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
  default     = "infra-480802"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast3"
}

variable "environment" {
  description = "환경 (prod, dev, staging)"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "도메인 이름"
  type        = string
  default     = "woohalabs.com"
}

variable "budget_amount" {
  description = "월 예산 (USD)"
  type        = number
  default     = 130
}

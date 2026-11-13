# Monitoring Module
# Cloud Monitoring 지표(Cloud SQL CPU·메모리·디스크 등)를 클러스터 안 Prometheus로 가져오기 위한
# 읽기 전용 GCP 서비스 계정 + Workload Identity 바인딩.
# - 사용처: monitoring 네임스페이스의 prometheus-stackdriver-exporter (ArgoCD가 Helm으로 배포)
# - KSA 자체는 Helm 차트가 만들고, 이 모듈은 GSA·권한·바인딩만 관리한다.
# - 문서: claudedocs/cloudsql-monitoring.md

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.13.0"
    }
  }
}

# Cloud Monitoring 읽기 전용 GCP 서비스 계정
resource "google_service_account" "monitoring_reader" {
  account_id   = "monitoring-reader-${var.environment}"
  display_name = "Cloud Monitoring Reader for ${var.environment}"
  project      = var.project_id
  description  = "prometheus-stackdriver-exporter가 Cloud Monitoring 지표(Cloud SQL 등)를 읽기 위한 계정 (읽기 전용)"
}

# Cloud Monitoring 지표 읽기 권한 (쓰기·설정 변경 권한 없음)
resource "google_project_iam_member" "monitoring_reader_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.monitoring_reader.email}"
}

# Workload Identity: KSA monitoring/prometheus-stackdriver-exporter → GSA
resource "google_service_account_iam_member" "monitoring_reader_workload_identity" {
  service_account_id = google_service_account.monitoring_reader.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.kubernetes_service_account}]"
}

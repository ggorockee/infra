output "monitoring_reader_email" {
  description = "Cloud Monitoring 읽기 전용 GSA 이메일 (stackdriver-exporter KSA 어노테이션 iam.gke.io/gcp-service-account 값)"
  value       = google_service_account.monitoring_reader.email
}

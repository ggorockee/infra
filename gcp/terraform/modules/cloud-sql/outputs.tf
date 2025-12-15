# Cloud SQL Outputs

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = google_sql_database_instance.main.connection_name
}

output "private_ip_address" {
  description = "Cloud SQL Private IP address"
  value       = google_sql_database_instance.main.private_ip_address
}

output "ojeomneo_database_name" {
  description = "Ojeomneo database name"
  value       = google_sql_database.ojeomneo.name
}

output "reviewmaps_database_name" {
  description = "ReviewMaps database name"
  value       = google_sql_database.reviewmaps.name
}

output "ojeomneo_user_name" {
  description = "Ojeomneo database user name"
  value       = google_sql_user.ojeomneo.name
}

output "reviewmaps_user_name" {
  description = "ReviewMaps database user name"
  value       = google_sql_user.reviewmaps.name
}

# GCP Service Account for ArgoCD
resource "google_service_account" "argocd" {
  account_id   = "argocd-${var.environment}"
  display_name = "ArgoCD Service Account for ${var.environment}"
  project      = var.project_id
}

# Workload Identity binding
resource "google_service_account_iam_member" "argocd_workload_identity" {
  service_account_id = google_service_account.argocd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.argocd_namespace}/argocd-server]"
}

# Grant Secret Manager access to ArgoCD service account
resource "google_secret_manager_secret_iam_member" "argocd_dex_client_id" {
  secret_id = "argocd-dex-google-client-id"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.argocd.email}"
  project   = var.project_id
}

resource "google_secret_manager_secret_iam_member" "argocd_dex_client_secret" {
  secret_id = "argocd-dex-google-client-secret"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.argocd.email}"
  project   = var.project_id
}

resource "google_secret_manager_secret_iam_member" "argocd_admin_password" {
  secret_id = "argocd-admin-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.argocd.email}"
  project   = var.project_id
}

resource "google_secret_manager_secret_iam_member" "argocd_admin_emails" {
  secret_id = "argocd-admin-emails"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.argocd.email}"
  project   = var.project_id
}

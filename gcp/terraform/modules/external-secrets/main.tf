# External Secrets Operator Module
# This module deploys External Secrets Operator via Helm and configures Workload Identity

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.13.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16.1"
    }
  }
}

# External Secrets Operator namespace
resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      environment = var.environment
    }
  }
}

# GCP Service Account for External Secrets Operator
resource "google_service_account" "external_secrets" {
  account_id   = "external-secrets-${var.environment}"
  display_name = "External Secrets Operator Service Account for ${var.environment}"
  project      = var.project_id
  description  = "Service Account for External Secrets Operator to access Secret Manager"
}

# Grant Secret Manager Secret Accessor role to the GCP Service Account
resource "google_project_iam_member" "external_secrets_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secrets.email}"
}

# Workload Identity binding: GKE SA -> GCP SA
resource "google_service_account_iam_member" "external_secrets_workload_identity" {
  service_account_id = google_service_account.external_secrets.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.service_account_name}]"
}

# Kubernetes Service Account for External Secrets Operator
resource "kubernetes_service_account" "external_secrets" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.external_secrets.email
    }
  }
  depends_on = [google_service_account_iam_member.external_secrets_workload_identity]
}

# External Secrets Operator Helm Release
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.helm_chart_version
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.external_secrets.metadata[0].name
      }
      resources = {
        limits = {
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
      webhook = {
        resources = {
          limits = {
            memory = "128Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }
      }
      certController = {
        resources = {
          limits = {
            memory = "128Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.external_secrets,
    google_project_iam_member.external_secrets_secret_accessor
  ]
}

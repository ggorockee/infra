# cert-manager Module
# Purpose: Deploy cert-manager with Cloud DNS integration for wildcard certificates

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
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

# Namespace for cert-manager
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
    labels = {
      "istio-injection" = "disabled"
    }
  }
}

# GCP Service Account for Cloud DNS (DNS-01 Challenge)
resource "google_service_account" "cert_manager_dns" {
  account_id   = "cert-manager-dns01-${var.environment}"
  display_name = "cert-manager DNS-01 Solver"
  description  = "Service Account for cert-manager to manage Cloud DNS records for DNS-01 challenge"
  project      = var.project_id
}

# IAM Role: DNS Administrator (for DNS-01 challenge)
resource "google_project_iam_member" "cert_manager_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.cert_manager_dns.email}"
}

# Workload Identity Binding
resource "google_service_account_iam_member" "cert_manager_workload_identity" {
  service_account_id = google_service_account.cert_manager_dns.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[cert-manager/cert-manager]"
}

# Kubernetes Service Account for cert-manager
resource "kubernetes_service_account" "cert_manager" {
  metadata {
    name      = "cert-manager"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.cert_manager_dns.email
    }
  }
}

# GCP Service Account Key (for DNS-01 solver)
resource "google_service_account_key" "cert_manager_dns_key" {
  service_account_id = google_service_account.cert_manager_dns.name
}

# Kubernetes Secret for Cloud DNS credentials
resource "kubernetes_secret" "clouddns_dns01_solver" {
  metadata {
    name      = "clouddns-dns01-solver-sa"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }

  data = {
    "key.json" = base64decode(google_service_account_key.cert_manager_dns_key.private_key)
  }

  type = "Opaque"
}

# Deploy cert-manager via Helm
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.16.2"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = kubernetes_namespace.cert_manager.metadata[0].name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.cert_manager.metadata[0].name
  }

  depends_on = [
    kubernetes_namespace.cert_manager,
    kubernetes_service_account.cert_manager,
    kubernetes_secret.clouddns_dns01_solver
  ]
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

module "networking" {
  source = "../../modules/networking"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}

module "gke" {
  source = "../../modules/gke"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  network_id    = module.networking.network_id
  subnet_id     = module.networking.private_subnet_id
}

# Phase 1: Networking and GKE only
# Other modules will be enabled in future phases
# GKE API has been enabled in GCP project

# module "cloud_sql" {
#   source = "../../modules/cloud-sql"
#
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
# }

# module "dns" {
#   source = "../../modules/dns"
#
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
# }

# module "cloud_armor" {
#   source = "../../modules/cloud-armor"
#
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
# }

# module "ssl_certificate" {
#   source = "../../modules/ssl-certificate"
#
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
# }

# module "load_balancer" {
#   source = "../../modules/load-balancer"
#
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
# }

# module "external_secrets" {
#   source = "../../modules/external-secrets"
#
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
# }

# module "iam" {
#   source = "../../modules/iam"
#
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
# }

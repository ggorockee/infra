provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Kubernetes and Helm providers for External Secrets deployment
data "google_client_config" "default" {}

data "google_container_cluster" "primary" {
  name       = module.gke.cluster_name
  location   = module.gke.cluster_location
  depends_on = [module.gke]
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
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
  zone        = var.zone
  environment = var.environment

  network_id = module.networking.network_id
  subnet_id  = module.networking.private_subnet_id

  # Spot instance configuration
  # e2-medium pool: 1-3 nodes (2 vCPU, 4GB RAM)
  # e2-standard-2 pool: 0-3 nodes (2 vCPU, 8GB RAM)
  node_count     = 1
  min_node_count = 1
  max_node_count = 3
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

# Phase 2: External Secrets Operator deployment
module "external_secrets" {
  source = "../../modules/external-secrets"

  project_id       = var.project_id
  region           = var.region
  environment      = var.environment
  cluster_name     = module.gke.cluster_name
  cluster_location = module.gke.cluster_location

  depends_on = [module.gke]
}

# module "iam" {
#   source = "../../modules/iam"
#
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
# }

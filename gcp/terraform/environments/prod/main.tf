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

module "cloud_sql" {
  source = "../../modules/cloud-sql"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  network_id = module.networking.network_id
}

module "dns" {
  source = "../../modules/dns"

  project_id  = var.project_id
  domain_name = var.domain_name
}

module "cloud_armor" {
  source = "../../modules/cloud-armor"

  project_id  = var.project_id
  environment = var.environment
}

module "ssl_certificate" {
  source = "../../modules/ssl-certificate"

  project_id  = var.project_id
  domain_name = var.domain_name
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  project_id  = var.project_id
  environment = var.environment

  ssl_certificate_id = module.ssl_certificate.certificate_id
  security_policy_id = module.cloud_armor.security_policy_id
}

module "external_secrets" {
  source = "../../modules/external-secrets"

  project_id  = var.project_id
  environment = var.environment
}

module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  environment = var.environment
}

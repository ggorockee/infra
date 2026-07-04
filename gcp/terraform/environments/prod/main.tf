provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
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
  # e2-medium pool: Fixed 2 nodes (2 vCPU, 4GB RAM)
  # e2-standard-2 pool: 2-3 nodes (2 vCPU, 8GB RAM)
  # 최적화: 리소스 사용률 분석 결과 3개 노드로 충분 (CPU 30%, Memory 51% 평균 사용률)
  node_count     = 2
  min_node_count = 2
  max_node_count = 3
}

# Phase 1: Networking and GKE only
# Other modules will be enabled in future phases
# GKE API has been enabled in GCP project

# Phase 2: Cloud SQL 활성화
module "cloud_sql" {
  source = "../../modules/cloud-sql"

  project_id     = var.project_id
  region         = var.region
  environment    = var.environment
  vpc_network_id = module.networking.network_id

  # Cloud SQL 설정
  instance_tier       = "db-g1-small"
  disk_size_gb        = 20
  deletion_protection = true

  depends_on = [module.gke]
}

# module "dns" {
#   source = "../../modules/dns"
#
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
# }

# Phase 3: Cloud Armor Security Policy
module "cloud_armor" {
  source = "../../modules/cloud-armor"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}

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
# NOTE: 신규 프로젝트 최초 부트스트랩 시 임시로 비활성화.
# kubernetes_manifest 리소스는 GKE 클러스터가 이미 존재해야 REST client를 구성할 수 있는데,
# 최초 apply에서는 GKE 클러스터도 함께 생성되므로 plan 단계에서 실패함.
# GKE 클러스터가 생성된 뒤 별도 커밋으로 재활성화할 것.
# module "external_secrets" {
#   source = "../../modules/external-secrets"
#
#   project_id       = var.project_id
#   region           = var.region
#   environment      = var.environment
#   cluster_name     = module.gke.cluster_name
#   cluster_location = module.gke.cluster_location
#
#   depends_on = [module.gke]
# }

# Phase 3: ArgoCD deployment
# NOTE: ArgoCD is now managed by Helm/ArgoCD itself, not by Terraform
# The resources have been removed from Terraform state but remain in the cluster
# See: .github/workflows/terraform-state-remove-argocd.yml
#
# module "argocd" {
#   source = "../../modules/argocd"
#
#   project_id       = var.project_id
#   region           = var.region
#   environment      = var.environment
#   cluster_name     = module.gke.cluster_name
#   cluster_location = module.gke.cluster_location
#
#   # ArgoCD domain (for OAuth redirect URIs and Istio VirtualService)
#   argocd_domain = "argocd.ggorockee.com"
#
#   depends_on = [module.external_secrets]
# }

# Phase 4: cert-manager deployment
# Note: cert-manager is already deployed manually via Helm/ArgoCD
# Commenting out to avoid conflicts with existing resources
# module "cert_manager" {
#   source = "../../modules/cert-manager"
#
#   project_id       = var.project_id
#   region           = var.region
#   environment      = var.environment
#   cluster_name     = module.gke.cluster_name
#   cluster_location = module.gke.cluster_location
#
#   depends_on = [module.argocd]
# }

# module "iam" {
#   source = "../../modules/iam"
#
#   project_id  = var.project_id
#   region      = var.region
#   environment = var.environment
# }


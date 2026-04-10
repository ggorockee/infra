terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.13.0"
    }
  }
}

# GKE Standard Cluster with Spot Instances
# Node pool migration: e2-medium (2 vCPU, 4GB) → e2-standard-2 (2 vCPU, 8GB RAM)
resource "google_container_cluster" "primary" {
  name     = "woohalabs-${var.environment}-gke"
  location = var.zone # Single zone for free tier
  project  = var.project_id

  network    = var.network_id
  subnetwork = var.subnet_id

  # Remove default node pool (we'll create it separately with Spot instances)
  remove_default_node_pool = true
  initial_node_count       = 1

  # Workload Identity for External Secrets
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  # 비용 최적화: 워크로드 로그/메트릭 비활성화
  # Cloud Logging - 시스템 컴포넌트만 수집 (앱 로그 제외 → Cloud Logging 비용 80%+ 절감)
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  # Cloud Monitoring - 시스템 메트릭만 수집 (워크로드 메트릭 제외)
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }
}

# Node Pool with Spot Instances - e2-medium (2 vCPU, 4GB RAM)
resource "google_container_node_pool" "spot_pool_medium" {
  name       = "woohalabs-${var.environment}-spot-medium"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  project    = var.project_id
  node_count = 0 # Scale down to 0, migrating to e2-standard-2

  node_config {
    spot         = true # Enable Spot instances
    machine_type = "e2-medium"

    # Google recommended settings for spot instances
    disk_size_gb = 30
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      environment  = var.environment
      node_type    = "spot"
      machine_size = "medium"
    }

    tags = ["gke-node", "${var.environment}"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = 0
    max_node_count = 0
  }
}

# Node Pool with Spot Instances - e2-highmem-2 (2 vCPU, 16GB RAM)
# 크롤링 워크로드 최적화: 메모리 집약 작업으로 인해 highmem 타입 선택
# e2-standard-2 대비 동일 vCPU, 메모리 2배, 비용 ~35% 증가
# max 3노드로도 32GB 초과 가능 (e2-standard-2 max 4노드 = 32GB와 동급 비용)
resource "google_container_node_pool" "spot_pool_large" {
  name       = "woohalabs-${var.environment}-spot-large"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  project    = var.project_id
  node_count = 2

  node_config {
    spot         = true
    machine_type = "e2-highmem-2"

    disk_size_gb = 30
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      environment  = var.environment
      node_type    = "spot"
      machine_size = "highmem"
    }

    tags = ["gke-node", "${var.environment}"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = 2
    max_node_count = 3
  }
}

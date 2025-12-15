# Cloud SQL PostgreSQL 인스턴스 및 데이터베이스 구성
# Secret Manager에서 DB credentials를 읽어 사용자 생성
# VPC Peering을 통한 Private IP 전용 연결

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
  }
}

# ============================================================
# Secret Manager에서 DB Credentials 읽기
# ============================================================

# Ojeomneo DB Credentials (JSON 형식)
data "google_secret_manager_secret_version" "ojeomneo_db_credentials" {
  secret  = "prod-ojeomneo-db-credentials"
  project = var.project_id
}

# ReviewMaps DB Credentials (JSON 형식)
data "google_secret_manager_secret_version" "reviewmaps_db_credentials" {
  secret  = "prod-reviewmaps-db-credentials"
  project = var.project_id
}

# JSON 파싱을 위한 로컬 변수
locals {
  # Ojeomneo credentials
  ojeomneo_creds = jsondecode(data.google_secret_manager_secret_version.ojeomneo_db_credentials.secret_data)
  ojeomneo_user  = nonsensitive(local.ojeomneo_creds.POSTGRES_USER)
  ojeomneo_pass  = local.ojeomneo_creds.POSTGRES_PASSWORD
  ojeomneo_db    = nonsensitive(local.ojeomneo_creds.POSTGRES_DB)

  # ReviewMaps credentials
  reviewmaps_creds = jsondecode(data.google_secret_manager_secret_version.reviewmaps_db_credentials.secret_data)
  reviewmaps_user  = nonsensitive(local.reviewmaps_creds.POSTGRES_USER)
  reviewmaps_pass  = local.reviewmaps_creds.POSTGRES_PASSWORD
  reviewmaps_db    = nonsensitive(local.reviewmaps_creds.POSTGRES_DB)
}

# ============================================================
# Cloud SQL Instance (PostgreSQL 15)
# ============================================================

resource "google_sql_database_instance" "main" {
  name             = "${var.environment}-woohalabs-cloudsql"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  # 삭제 보호 (프로덕션 환경)
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.instance_tier
    availability_type = "ZONAL" # 비용 최적화

    # Disk 설정
    disk_type = "PD_SSD"
    disk_size = var.disk_size_gb

    # 백업 설정 (비용 최적화: 수동 백업만 사용)
    backup_configuration {
      enabled                        = false
      point_in_time_recovery_enabled = false
    }

    # IP 설정 (Private IP + Public IP for management)
    ip_configuration {
      ipv4_enabled                                  = true  # Enable for gcloud sql connect
      private_network                               = var.vpc_network_id
      enable_private_path_for_google_cloud_services = true

      # Authorized networks (GitHub Actions runner IP ranges)
      authorized_networks {
        name  = "github-actions"
        value = "0.0.0.0/0"  # Temporarily allow all for initial setup
      }
    }

    # Maintenance window
    maintenance_window {
      day          = 7 # Sunday
      hour         = 3 # 3 AM KST
      update_track = "stable"
    }

    # Database flags (PostgreSQL 15 최적화)
    database_flags {
      name  = "max_connections"
      value = "100"
    }

    database_flags {
      name  = "shared_buffers"
      value = "32768" # 256MB (페이지 단위: 8KB)
    }

    database_flags {
      name  = "effective_cache_size"
      value = "98304" # 768MB
    }

    database_flags {
      name  = "work_mem"
      value = "4096" # 4MB
    }
  }

  # VPC Peering이 먼저 생성되어야 함
  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]
}

# ============================================================
# Private VPC Connection (VPC Peering)
# ============================================================

resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.environment}-cloudsql-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_network_id
  project       = var.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# ============================================================
# ============================================================
# Database 생성
# ============================================================
# PostgreSQL Extensions (pgcrypto, postgis)는 reviewmaps_ownership에서 SQL로 활성화됨

# Ojeomneo Database
resource "google_sql_database" "ojeomneo" {
  name     = local.ojeomneo_db
  instance = google_sql_database_instance.main.name
  project  = var.project_id

  # Character set
  charset   = "UTF8"
  collation = "en_US.UTF8"

  depends_on = [google_sql_database_instance.main]

  # Prevent accidental recreation due to sensitive attribute changes
  lifecycle {
    ignore_changes = [name]
  }
}

# ReviewMaps Database
resource "google_sql_database" "reviewmaps" {
  name     = local.reviewmaps_db
  instance = google_sql_database_instance.main.name
  project  = var.project_id

  # Character set
  charset   = "UTF8"
  collation = "en_US.UTF8"

  depends_on = [google_sql_database_instance.main]

  # Prevent accidental recreation due to sensitive attribute changes
  lifecycle {
    ignore_changes = [name]
  }
}

# ============================================================
# Database Users (Secret Manager에서 가져온 credentials 사용)
# ============================================================

# Ojeomneo User
resource "google_sql_user" "ojeomneo" {
  name     = local.ojeomneo_user
  instance = google_sql_database_instance.main.name
  password = local.ojeomneo_pass
  project  = var.project_id

  depends_on = [google_sql_database.ojeomneo]

  # Prevent accidental recreation due to sensitive attribute changes
  lifecycle {
    ignore_changes = [name]
  }
}

# ReviewMaps User
resource "google_sql_user" "reviewmaps" {
  name     = local.reviewmaps_user
  instance = google_sql_database_instance.main.name
  password = local.reviewmaps_pass
  project  = var.project_id

  depends_on = [google_sql_database.reviewmaps]

  # Prevent accidental recreation due to sensitive attribute changes
  lifecycle {
    ignore_changes = [name]
  }
}

# ============================================================
# Database 소유권 및 권한 설정
# ============================================================

# Ojeomneo DB 소유권 설정
resource "null_resource" "ojeomneo_ownership" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud sql connect ${google_sql_database_instance.main.name} \
        --user=postgres \
        --database=${local.ojeomneo_db} \
        --quiet \
        --project=${var.project_id} <<SQL
      ALTER DATABASE ${local.ojeomneo_db} OWNER TO ${local.ojeomneo_user};
      GRANT ALL PRIVILEGES ON DATABASE ${local.ojeomneo_db} TO ${local.ojeomneo_user};
      SQL
    EOT
  }

  depends_on = [google_sql_user.ojeomneo]
}

# ReviewMaps DB 소유권 설정 및 PostGIS extension 활성화
resource "null_resource" "reviewmaps_ownership" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud sql connect ${google_sql_database_instance.main.name} \
        --user=postgres \
        --database=${local.reviewmaps_db} \
        --quiet \
        --project=${var.project_id} <<SQL
      ALTER DATABASE ${local.reviewmaps_db} OWNER TO ${local.reviewmaps_user};
      GRANT ALL PRIVILEGES ON DATABASE ${local.reviewmaps_db} TO ${local.reviewmaps_user};

      -- PostGIS extension 활성화 (공간 데이터 지원)
      CREATE EXTENSION IF NOT EXISTS postgis;
      CREATE EXTENSION IF NOT EXISTS pgcrypto;
      SQL
    EOT
  }

  depends_on = [
    google_sql_user.reviewmaps
  ]
}

# ============================================================
# Secret Manager에 연결 정보 업데이트
# ============================================================

# Ojeomneo DB 연결 정보 업데이트 (POSTGRES_SERVER를 Cloud SQL Private IP로 변경)
resource "null_resource" "update_ojeomneo_secret" {
  provisioner "local-exec" {
    command = <<-EOT
      # 기존 Secret에서 모든 키 가져오기
      EXISTING_SECRET=$(gcloud secrets versions access latest \
        --secret=prod-ojeomneo-db-credentials \
        --project=${var.project_id})

      # POSTGRES_SERVER만 Cloud SQL Private IP로 업데이트
      UPDATED_SECRET=$(echo "$EXISTING_SECRET" | jq \
        --arg server "${google_sql_database_instance.main.private_ip_address}" \
        '.POSTGRES_SERVER = $server')

      # 새 버전 추가
      echo -n "$UPDATED_SECRET" | gcloud secrets versions add prod-ojeomneo-db-credentials \
        --data-file=- \
        --project=${var.project_id}
    EOT
  }

  depends_on = [google_sql_database_instance.main]
}

# ReviewMaps DB 연결 정보 업데이트 (POSTGRES_SERVER를 Cloud SQL Private IP로 변경)
resource "null_resource" "update_reviewmaps_secret" {
  provisioner "local-exec" {
    command = <<-EOT
      # 기존 Secret에서 모든 키 가져오기
      EXISTING_SECRET=$(gcloud secrets versions access latest \
        --secret=prod-reviewmaps-db-credentials \
        --project=${var.project_id})

      # POSTGRES_SERVER만 Cloud SQL Private IP로 업데이트
      UPDATED_SECRET=$(echo "$EXISTING_SECRET" | jq \
        --arg server "${google_sql_database_instance.main.private_ip_address}" \
        '.POSTGRES_SERVER = $server')

      # 새 버전 추가
      echo -n "$UPDATED_SECRET" | gcloud secrets versions add prod-reviewmaps-db-credentials \
        --data-file=- \
        --project=${var.project_id}
    EOT
  }

  depends_on = [google_sql_database_instance.main]
}

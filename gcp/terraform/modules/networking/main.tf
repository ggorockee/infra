terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.13.0"
    }
  }
}

# Use Default VPC Network
data "google_compute_network" "default" {
  name    = "default"
  project = var.project_id
}

# Use Default Subnet in specified region
data "google_compute_subnetwork" "default" {
  name    = "default"
  region  = var.region
  project = var.project_id
}

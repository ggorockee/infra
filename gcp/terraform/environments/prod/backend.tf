terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {
    bucket = "woohalabs-terraform-state"
    prefix = "env/prod"
  }

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

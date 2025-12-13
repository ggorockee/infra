terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {
    bucket = "woohalabs-terraform-state"
    prefix = "env/prod"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

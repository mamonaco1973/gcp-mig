# ================================================================================
# Provider Configuration
# Authenticates via credentials.json — the service account key generated during
# GCP project setup. Project ID is read from the key file so no variable needed.
# ================================================================================

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project     = local.credentials.project_id
  credentials = file("../credentials.json")
  region      = "us-central1"
}

locals {
  credentials = jsondecode(file("../credentials.json"))
}

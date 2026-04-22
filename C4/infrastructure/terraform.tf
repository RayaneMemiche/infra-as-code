# C4 Final Project - Terraform Configuration
# Provider and Backend Configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # Remote state in GCS - use existing bucket from C2
  backend "gcs" {
    bucket = "tfstate-fourth-outpost-479614-t4"
    prefix = "c4/terraform/state"
  }
}

# Google Provider - NO credentials hardcoded
# Authentication via:
# - Local: gcloud auth application-default login
# - CI/CD: Workload Identity Federation (OIDC)
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Kubernetes provider - configured after GKE cluster creation
provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

# Helm provider - configured after GKE cluster creation
provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  }
}

# Data source for GCP auth token (used by K8S/Helm providers)
data "google_client_config" "default" {}

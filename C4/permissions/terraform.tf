# C4 Permissions Stack - Terraform Configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "tfstate-fourth-outpost-479614-t4"
    prefix = "permissions/dev"  # Separate state from infrastructure
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "github" {
  owner = var.github_owner
}

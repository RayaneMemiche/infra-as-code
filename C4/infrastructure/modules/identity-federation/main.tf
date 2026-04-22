# Workload Identity Federation Module
# Enables GitHub Actions to authenticate to GCP without long-lived credentials

# ============================================================================
# WORKLOAD IDENTITY POOL
# ============================================================================

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions CI/CD"
  disabled                  = false

  # CRITICAL: Never destroy - takes 30 days to fully delete and breaks all CI/CD
  lifecycle {
    prevent_destroy = true
  }
}

# ============================================================================
# WORKLOAD IDENTITY PROVIDER (OIDC)
# ============================================================================

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_provider_id
  display_name                       = "GitHub Actions Provider"
  description                        = "OIDC provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.ref_type"   = "assertion.ref_type"
  }

  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # CRITICAL: Never destroy - coupled with WIF Pool, breaks all CI/CD
  lifecycle {
    prevent_destroy = true
  }
}

# ============================================================================
# SERVICE ACCOUNT FOR TERRAFORM
# ============================================================================

resource "google_service_account" "terraform" {
  project      = var.project_id
  account_id   = "terraform-${var.environment}"
  display_name = "Terraform Service Account (${var.environment})"
  description  = "Service Account for Terraform operations via GitHub Actions"
}

# ============================================================================
# SERVICE ACCOUNT IAM ROLES
# ============================================================================

locals {
  terraform_roles = [
    "roles/compute.admin",                   # VPC, Subnets, Firewall
    "roles/container.admin",                 # GKE
    "roles/cloudsql.admin",                  # Cloud SQL
    "roles/iam.serviceAccountAdmin",         # Service Accounts
    "roles/iam.serviceAccountUser",          # Act as Service Account
    "roles/storage.admin",                   # GCS for state
    "roles/resourcemanager.projectIamAdmin", # IAM bindings
    "roles/artifactregistry.admin",          # Container images
    "roles/logging.admin",                   # Logging
    "roles/monitoring.admin",                # Monitoring
    "roles/servicenetworking.networksAdmin", # Private Service Connection
    "roles/secretmanager.admin",             # Secret Manager (for database credentials)
  ]
}

resource "google_project_iam_member" "terraform_roles" {
  for_each = toset(local.terraform_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

# ============================================================================
# WORKLOAD IDENTITY BINDING
# ============================================================================

# Allow GitHub Actions from specific repo to impersonate the service account
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# Alternative: More restrictive binding (only specific branches)
# Uncomment to restrict to specific branches (e.g., main, develop)
# resource "google_service_account_iam_member" "workload_identity_binding_main" {
#   service_account_id = google_service_account.terraform.name
#   role               = "roles/iam.workloadIdentityUser"
#   member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.ref/refs/heads/main"
# }

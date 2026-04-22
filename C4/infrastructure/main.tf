# C4 Final Project - Main Infrastructure Configuration

# ============================================================================
# ENABLE REQUIRED GCP APIs
# ============================================================================

locals {
  required_apis = [
    "compute.googleapis.com",              # VPC, Subnets, Firewall
    "container.googleapis.com",            # GKE
    "sqladmin.googleapis.com",             # Cloud SQL
    "servicenetworking.googleapis.com",    # Private Service Connection
    "iam.googleapis.com",                  # IAM
    "iamcredentials.googleapis.com",       # Service Account Credentials
    "cloudresourcemanager.googleapis.com", # Resource Manager
    "sts.googleapis.com",                  # Security Token Service (WIF)
    "artifactregistry.googleapis.com",     # Container Registry
    "logging.googleapis.com",              # Cloud Logging
    "monitoring.googleapis.com",           # Cloud Monitoring
    "secretmanager.googleapis.com",        # Secret Manager (for DB credentials)
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ============================================================================
# WORKLOAD IDENTITY FEDERATION (Phase 1)
# ============================================================================

module "identity_federation" {
  source = "./modules/identity-federation"

  project_id      = var.project_id
  github_repo     = var.github_repo
  wif_pool_id     = var.wif_pool_id
  wif_provider_id = var.wif_provider_id
  environment     = var.environment

  depends_on = [google_project_service.apis]
}

# ============================================================================
# TEAM ACCESS - MOVED TO SEPARATE STACK
# ============================================================================
# Team access (professors, students, billing) is now managed in:
# /C4/permissions/
#
# This separation allows:
# - Independent lifecycle management
# - Different access controls for infra vs permissions
# - Isolated state files to reduce blast radius
# ============================================================================

# ============================================================================
# NETWORKING (Phase 1.2)
# ============================================================================

module "networking" {
  source = "./modules/networking"

  project_id    = var.project_id
  region        = var.region
  vpc_name      = var.vpc_name
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
  labels        = var.labels
  environment   = var.environment

  depends_on = [google_project_service.apis]
}

# ============================================================================
# GKE CLUSTER (Phase 1.3)
# ============================================================================

module "gke" {
  source = "./modules/gke"

  # Project settings
  project_id   = var.project_id
  region       = var.region
  zone         = var.zone
  environment  = var.environment
  cluster_name = var.gke_cluster_name

  # Network configuration (from networking module)
  vpc_name            = module.networking.vpc_name
  subnet_name         = module.networking.subnet_name
  pods_range_name     = module.networking.pods_range_name
  services_range_name = module.networking.services_range_name

  # Application configuration
  app_name = var.app_name

  # Node pool configuration (application pool)
  app_pool_machine_type  = var.gke_node_machine_type
  app_pool_min_nodes     = var.gke_min_nodes
  app_pool_max_nodes     = var.gke_max_nodes
  app_pool_initial_nodes = var.gke_initial_nodes

  # Use preemptible for cost savings in dev
  use_preemptible_nodes = var.environment == "dev" ? true : false

  # Disable deletion protection in dev
  deletion_protection = var.environment == "prd" ? true : false

  labels = var.labels

  depends_on = [module.networking]
}

# ============================================================================
# ARTIFACT REGISTRY (for Docker images)
# ============================================================================

resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = "c4-images"
  description   = "Docker images for C4 project applications"
  format        = "DOCKER"

  labels = var.labels

  depends_on = [google_project_service.apis]
}

# ============================================================================
# DATABASE (Cloud SQL PostgreSQL)
# ============================================================================

module "database" {
  source = "./modules/database"

  project_id    = var.project_id
  region        = var.region
  environment   = var.environment
  instance_name = var.db_instance_name
  db_tier       = var.db_tier
  db_name       = var.db_name
  db_user       = var.db_user

  # Network configuration
  network_id             = module.networking.vpc_id
  private_vpc_connection = module.networking.private_vpc_connection

  # Grant secret access to the app service account
  app_service_account_email = module.gke.app_service_account_email

  labels = var.labels

  depends_on = [module.networking, module.gke]
}

# ============================================================================
# MONITORING STACK (Section 6.3)
# ============================================================================

module "monitoring" {
  source = "./modules/monitoring"

  environment            = var.environment
  grafana_admin_password = var.grafana_admin_password

  # Prometheus configuration - reduced for cost savings
  prometheus_retention    = var.environment == "prd" ? "15d" : "7d"
  prometheus_storage_size = var.environment == "prd" ? "10Gi" : "5Gi"

  labels = var.labels

  depends_on = [module.gke]
}

# ============================================================================
# LOAD BALANCER (Phase 4) - Uncomment when ready
# ============================================================================

# module "load_balancer" {
#   source = "./modules/load-balancer"
#
#   project_id = var.project_id
#   region     = var.region
#   network_id = module.networking.vpc_id
#   labels     = var.labels
#
#   depends_on = [module.gke]
# }

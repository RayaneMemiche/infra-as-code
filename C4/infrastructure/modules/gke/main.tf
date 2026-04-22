# GKE Module
# Creates a private GKE cluster with Workload Identity and multiple node pools

# ============================================================================
# GKE CLUSTER
# ============================================================================

resource "google_container_cluster" "main" {
  project  = var.project_id
  name     = var.cluster_name
  location = var.zone

  # We use separately managed node pools
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration
  network    = var.vpc_name
  subnetwork = var.subnet_name

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_cidr
  }

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Master authorized networks (restrict control plane access)
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Workload Identity (required for secure pod authentication)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel for automatic upgrades
  release_channel {
    channel = var.release_channel
  }

  # Addons configuration
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = true # Calico addon désactivé - économise ~800m CPU
    }
    gcp_filestore_csi_driver_config {
      enabled = false
    }
  }

  # Network policy - DÉSACTIVÉ pour réduire l'overhead système
  # Les firewall rules GCP assurent la sécurité au niveau VPC
  network_policy {
    enabled = false
  }

  # Maintenance window - daily 4-hour window at 3 AM UTC
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Resource labels
  resource_labels = var.labels

  # Deletion protection (disable for dev, enable for prod)
  deletion_protection = var.deletion_protection

  # NOTE: prevent_destroy removed to allow terraform destroy
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# ============================================================================
# NODE POOL: APPLICATION
# ============================================================================
# Main node pool for application workloads

resource "google_container_node_pool" "application" {
  project  = var.project_id
  name     = "${var.cluster_name}-application"
  location = var.zone
  cluster  = google_container_cluster.main.name

  # Autoscaling configuration
  autoscaling {
    min_node_count = var.app_pool_min_nodes
    max_node_count = var.app_pool_max_nodes
  }

  initial_node_count = var.app_pool_initial_nodes

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Node configuration
  node_config {
    preemptible  = var.use_preemptible_nodes
    machine_type = var.app_pool_machine_type
    disk_size_gb = var.app_pool_disk_size
    disk_type    = "pd-standard"

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels
    labels = merge(var.labels, {
      pool = "application"
    })

    # Taints (none for application pool - default workload pool)
    # Add taints if you need dedicated pools

    # Tags for firewall rules
    tags = ["gke-node", "gke-${var.cluster_name}", "application-pool"]

    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

# ============================================================================
# NODE POOL: RUNNERS (for GitHub Actions self-hosted runners)
# ============================================================================

resource "google_container_node_pool" "runners" {
  project  = var.project_id
  name     = "${var.cluster_name}-runners"
  location = var.zone
  cluster  = google_container_cluster.main.name

  # Autoscaling configuration
  autoscaling {
    min_node_count = var.runners_pool_min_nodes
    max_node_count = var.runners_pool_max_nodes
  }

  initial_node_count = var.runners_pool_initial_nodes

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Node configuration
  node_config {
    preemptible  = true # Runners can use preemptible for cost savings
    machine_type = var.runners_pool_machine_type
    disk_size_gb = var.runners_pool_disk_size
    disk_type    = "pd-standard"

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels
    labels = merge(var.labels, {
      pool = "runners"
    })

    # Taint to ensure only runner pods are scheduled here
    taint {
      key    = "runner"
      value  = "true"
      effect = "NO_SCHEDULE"
    }

    # Tags for firewall rules
    tags = ["gke-node", "gke-${var.cluster_name}", "runners-pool"]

    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

# ============================================================================

# ============================================================================
# SERVICE ACCOUNTS FOR WORKLOAD IDENTITY
# ============================================================================

# Application Service Account
resource "google_service_account" "app_workload" {
  project      = var.project_id
  account_id   = "${var.app_name}-app-${var.environment}"
  display_name = "Application Workload Identity SA (${var.environment})"
  description  = "Service Account for application pods via Workload Identity"
}

# Runners Service Account
resource "google_service_account" "runners_workload" {
  project      = var.project_id
  account_id   = "${var.app_name}-runners-${var.environment}"
  display_name = "Runners Workload Identity SA (${var.environment})"
  description  = "Service Account for GitHub Actions runners via Workload Identity"
}

# ============================================================================
# WORKLOAD IDENTITY BINDINGS
# ============================================================================

# Allow Kubernetes SA to impersonate GCP SA (Application)
# Note: The Workload Identity pool is created when the GKE cluster is created
resource "google_service_account_iam_member" "app_workload_identity" {
  service_account_id = google_service_account.app_workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.app_namespace}/${var.app_name}]"

  depends_on = [google_container_cluster.main]
}

# Allow Kubernetes SA to impersonate GCP SA (Runners)
resource "google_service_account_iam_member" "runners_workload_identity" {
  service_account_id = google_service_account.runners_workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.runners_namespace}/github-runner]"

  depends_on = [google_container_cluster.main]
}

# ============================================================================
# IAM ROLES FOR SERVICE ACCOUNTS
# ============================================================================

# Application SA roles (access to Cloud SQL, Secret Manager, etc.)
locals {
  app_sa_roles = [
    "roles/cloudsql.client",              # Connect to Cloud SQL
    "roles/secretmanager.secretAccessor", # Access secrets
    "roles/logging.logWriter",            # Write logs
    "roles/monitoring.metricWriter",      # Write metrics
  ]

  runners_sa_roles = [
    "roles/artifactregistry.writer", # Push container images
    "roles/storage.objectViewer",    # Read GCS objects
    "roles/logging.logWriter",       # Write logs
  ]
}

resource "google_project_iam_member" "app_sa_roles" {
  for_each = toset(local.app_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.app_workload.email}"
}

resource "google_project_iam_member" "runners_sa_roles" {
  for_each = toset(local.runners_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.runners_workload.email}"
}

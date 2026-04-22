# Cloud SQL Database Module
# Creates a managed PostgreSQL instance with private IP for the Task Manager API

# ============================================================================
# RANDOM PASSWORD GENERATION
# ============================================================================

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ============================================================================
# CLOUD SQL INSTANCE
# ============================================================================

resource "google_sql_database_instance" "main" {
  name             = "${var.instance_name}-${var.environment}"
  project          = var.project_id
  region           = var.region
  database_version = var.database_version

  # Prevent accidental deletion in production
  deletion_protection = var.environment == "prd" ? true : false

  settings {
    tier              = var.db_tier
    availability_type = var.environment == "prd" ? "REGIONAL" : "ZONAL"
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    # Network configuration - Private IP only (no public IP)
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
    }

    # Backup configuration
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00" # 3 AM UTC
      point_in_time_recovery_enabled = var.environment == "prd" ? true : false
      transaction_log_retention_days = var.environment == "prd" ? 7 : 3
      backup_retention_settings {
        retained_backups = var.environment == "prd" ? 30 : 7
        retention_unit   = "COUNT"
      }
    }

    # Maintenance window (Sunday 4 AM)
    maintenance_window {
      day          = 7 # Sunday
      hour         = 4
      update_track = "stable"
    }

    # Database flags for performance and security
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    # Insights for query analysis
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = var.labels
  }

  # Ensure private service connection exists before creating instance
  depends_on = [var.private_vpc_connection]

  # NOTE: prevent_destroy removed to allow terraform destroy
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# ============================================================================
# DATABASE
# ============================================================================

resource "google_sql_database" "main" {
  name     = var.db_name
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  charset  = "UTF8"
}

# ============================================================================
# DATABASE USER
# ============================================================================

resource "google_sql_user" "main" {
  name     = var.db_user
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result

  # Prevent deletion if there are active connections
  deletion_policy = "ABANDON"
}

# ============================================================================
# SECRET MANAGER - Store Database Credentials
# ============================================================================

# Secret for database password
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.instance_name}-${var.environment}-db-password"
  project   = var.project_id

  labels = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# Secret for full database connection URL
resource "google_secret_manager_secret" "db_url" {
  secret_id = "${var.instance_name}-${var.environment}-db-url"
  project   = var.project_id

  labels = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_url" {
  secret = google_secret_manager_secret.db_url.id
  secret_data = format(
    "postgresql://%s:%s@%s:5432/%s",
    var.db_user,
    random_password.db_password.result,
    google_sql_database_instance.main.private_ip_address,
    var.db_name
  )
}

# ============================================================================
# IAM - Grant GKE Service Account access to secrets
# ============================================================================

# Allow the app service account to access the database URL secret
resource "google_secret_manager_secret_iam_member" "db_url_access" {
  count = var.app_service_account_email != "" ? 1 : 0

  project   = var.project_id
  secret_id = google_secret_manager_secret.db_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.app_service_account_email}"
}

# Allow the app service account to access the password secret (optional)
resource "google_secret_manager_secret_iam_member" "db_password_access" {
  count = var.app_service_account_email != "" ? 1 : 0

  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.app_service_account_email}"
}

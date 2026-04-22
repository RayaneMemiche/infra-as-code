# Cloud SQL Database Module - Outputs

# ============================================================================
# INSTANCE OUTPUTS
# ============================================================================

output "instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  description = "Connection name for Cloud SQL proxy (project:region:instance)"
  value       = google_sql_database_instance.main.connection_name
}

output "instance_self_link" {
  description = "Self-link of the Cloud SQL instance"
  value       = google_sql_database_instance.main.self_link
}

# ============================================================================
# NETWORK OUTPUTS
# ============================================================================

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.main.private_ip_address
}

# ============================================================================
# DATABASE OUTPUTS
# ============================================================================

output "database_name" {
  description = "Name of the database"
  value       = google_sql_database.main.name
}

output "database_user" {
  description = "Database username"
  value       = google_sql_user.main.name
}

# ============================================================================
# SECRET MANAGER OUTPUTS
# ============================================================================

output "db_password_secret_id" {
  description = "Secret Manager secret ID for database password"
  value       = google_secret_manager_secret.db_password.secret_id
}

output "db_url_secret_id" {
  description = "Secret Manager secret ID for database URL"
  value       = google_secret_manager_secret.db_url.secret_id
}

output "db_password_secret_version" {
  description = "Secret Manager secret version for database password"
  value       = google_secret_manager_secret_version.db_password.name
}

output "db_url_secret_version" {
  description = "Secret Manager secret version for database URL"
  value       = google_secret_manager_secret_version.db_url.name
}

# ============================================================================
# CONNECTION STRING (for Helm values)
# ============================================================================

output "connection_string" {
  description = "PostgreSQL connection string (without password - use secret)"
  value       = "postgresql://${var.db_user}@${google_sql_database_instance.main.private_ip_address}:5432/${var.db_name}"
  sensitive   = false
}

output "connection_string_full" {
  description = "Full PostgreSQL connection string (sensitive - use for testing only)"
  value = format(
    "postgresql://%s:%s@%s:5432/%s",
    var.db_user,
    random_password.db_password.result,
    google_sql_database_instance.main.private_ip_address,
    var.db_name
  )
  sensitive = true
}

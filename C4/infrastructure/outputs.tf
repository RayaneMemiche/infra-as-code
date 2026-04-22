# C4 Final Project - Output Values

# ============================================================================
# WORKLOAD IDENTITY FEDERATION OUTPUTS
# ============================================================================

output "wif_pool_name" {
  description = "Full name of the Workload Identity Pool"
  value       = module.identity_federation.pool_name
}

output "wif_provider_name" {
  description = "Full name of the Workload Identity Provider"
  value       = module.identity_federation.provider_name
}

output "terraform_service_account_email" {
  description = "Email of the Terraform service account"
  value       = module.identity_federation.service_account_email
}

output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = module.identity_federation.workload_identity_provider
}

# ============================================================================
# NETWORKING OUTPUTS
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC network"
  value       = module.networking.vpc_id
}

output "vpc_name" {
  description = "Name of the VPC network"
  value       = module.networking.vpc_name
}

output "subnet_id" {
  description = "ID of the main subnet"
  value       = module.networking.subnet_id
}

output "subnet_name" {
  description = "Name of the main subnet"
  value       = module.networking.subnet_name
}

output "pods_range_name" {
  description = "Name of the secondary IP range for pods"
  value       = module.networking.pods_range_name
}

output "services_range_name" {
  description = "Name of the secondary IP range for services"
  value       = module.networking.services_range_name
}

output "nat_name" {
  description = "Name of the Cloud NAT"
  value       = module.networking.nat_name
}

# ============================================================================
# GKE OUTPUTS
# ============================================================================

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "Endpoint of the GKE cluster (control plane)"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  description = "CA certificate of the GKE cluster"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true
}

output "gke_application_pool_name" {
  description = "Name of the application node pool"
  value       = module.gke.application_pool_name
}

output "gke_runners_pool_name" {
  description = "Name of the runners node pool"
  value       = module.gke.runners_pool_name
}


output "gke_workload_identity_pool" {
  description = "Workload Identity pool for GKE"
  value       = module.gke.workload_identity_pool
}

output "gke_app_service_account_email" {
  description = "Email of the application Workload Identity service account"
  value       = module.gke.app_service_account_email
}

output "gke_runners_service_account_email" {
  description = "Email of the runners Workload Identity service account"
  value       = module.gke.runners_service_account_email
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = module.gke.gcloud_get_credentials_command
}

# ============================================================================
# ARTIFACT REGISTRY OUTPUTS
# ============================================================================

output "artifact_registry_repository" {
  description = "Name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.images.repository_id
}

output "artifact_registry_url" {
  description = "URL of the Artifact Registry repository"
  value       = "${google_artifact_registry_repository.images.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

# ============================================================================
# DATABASE OUTPUTS (Cloud SQL)
# ============================================================================

output "database_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = module.database.instance_name
}

output "database_connection_name" {
  description = "Connection name of the Cloud SQL instance (project:region:instance)"
  value       = module.database.instance_connection_name
}

output "database_private_ip" {
  description = "Private IP of the Cloud SQL instance"
  value       = module.database.private_ip_address
  sensitive   = true
}

output "database_name" {
  description = "Name of the database"
  value       = module.database.database_name
}

output "database_user" {
  description = "Database username"
  value       = module.database.database_user
}

output "database_password_secret_id" {
  description = "Secret Manager secret ID for database password"
  value       = module.database.db_password_secret_id
}

output "database_url_secret_id" {
  description = "Secret Manager secret ID for full database URL"
  value       = module.database.db_url_secret_id
}

# ============================================================================
# GITHUB ACTIONS CONFIGURATION
# ============================================================================

output "github_actions_auth_config" {
  description = "Configuration for GitHub Actions authentication"
  value       = <<-EOT
    # Add these to your GitHub Actions workflow:

    - uses: google-github-actions/auth@v2
      with:
        workload_identity_provider: ${module.identity_federation.workload_identity_provider}
        service_account: ${module.identity_federation.service_account_email}
  EOT
}

# ============================================================================
# MONITORING OUTPUTS
# ============================================================================

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring stack"
  value       = module.monitoring.namespace
}

output "grafana_service" {
  description = "Grafana service name"
  value       = module.monitoring.grafana_service
}

output "prometheus_service" {
  description = "Prometheus service name"
  value       = module.monitoring.prometheus_service
}

output "grafana_port_forward_command" {
  description = "Command to port-forward Grafana for local access"
  value       = module.monitoring.grafana_port_forward_command
}

output "prometheus_port_forward_command" {
  description = "Command to port-forward Prometheus for local access"
  value       = module.monitoring.prometheus_port_forward_command
}

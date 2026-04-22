# GKE Module - Outputs

# ============================================================================
# CLUSTER OUTPUTS
# ============================================================================

output "cluster_id" {
  description = "Unique identifier for the cluster"
  value       = google_container_cluster.main.id
}

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.main.name
}

output "cluster_location" {
  description = "Location (zone) of the cluster"
  value       = google_container_cluster.main.location
}

output "cluster_endpoint" {
  description = "Endpoint for the GKE cluster (control plane)"
  value       = google_container_cluster.main.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded CA certificate for cluster authentication"
  value       = google_container_cluster.main.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_master_version" {
  description = "Current master version of the cluster"
  value       = google_container_cluster.main.master_version
}

# ============================================================================
# NODE POOL OUTPUTS
# ============================================================================

output "application_pool_name" {
  description = "Name of the application node pool"
  value       = google_container_node_pool.application.name
}

output "runners_pool_name" {
  description = "Name of the runners node pool"
  value       = google_container_node_pool.runners.name
}


# ============================================================================
# WORKLOAD IDENTITY OUTPUTS
# ============================================================================

output "workload_identity_pool" {
  description = "Workload Identity pool for the cluster"
  value       = "${var.project_id}.svc.id.goog"
}

output "app_service_account_email" {
  description = "Email of the application Workload Identity service account"
  value       = google_service_account.app_workload.email
}

output "runners_service_account_email" {
  description = "Email of the runners Workload Identity service account"
  value       = google_service_account.runners_workload.email
}

# ============================================================================
# KUBECONFIG HELPER OUTPUTS
# ============================================================================

output "gcloud_get_credentials_command" {
  description = "gcloud command to get cluster credentials"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --zone ${google_container_cluster.main.location} --project ${var.project_id}"
}

# ============================================================================
# KUBERNETES ANNOTATIONS FOR WORKLOAD IDENTITY
# ============================================================================

output "app_workload_identity_annotation" {
  description = "Annotation to add to Kubernetes ServiceAccount for app workload identity"
  value       = "iam.gke.io/gcp-service-account=${google_service_account.app_workload.email}"
}

output "runners_workload_identity_annotation" {
  description = "Annotation to add to Kubernetes ServiceAccount for runners workload identity"
  value       = "iam.gke.io/gcp-service-account=${google_service_account.runners_workload.email}"
}

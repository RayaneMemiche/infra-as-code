# Workload Identity Federation Module - Outputs

output "pool_name" {
  description = "Full name of the Workload Identity Pool"
  value       = google_iam_workload_identity_pool.github.name
}

output "pool_id" {
  description = "ID of the Workload Identity Pool"
  value       = google_iam_workload_identity_pool.github.workload_identity_pool_id
}

output "provider_name" {
  description = "Full name of the Workload Identity Provider"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "provider_id" {
  description = "ID of the Workload Identity Provider"
  value       = google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id
}

output "service_account_email" {
  description = "Email of the Terraform service account"
  value       = google_service_account.terraform.email
}

output "service_account_id" {
  description = "ID of the Terraform service account"
  value       = google_service_account.terraform.id
}

output "workload_identity_provider" {
  description = "Full Workload Identity Provider path for GitHub Actions"
  value       = "projects/${var.project_id}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
}

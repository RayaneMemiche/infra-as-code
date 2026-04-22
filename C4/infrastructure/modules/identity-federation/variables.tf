# Workload Identity Federation Module - Variables

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$", var.github_repo))
    error_message = "GitHub repo must be in format 'owner/repo'."
  }
}

variable "wif_pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-pool"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,31}$", var.wif_pool_id))
    error_message = "Pool ID must be 4-32 characters, start with letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "wif_provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
  default     = "github-provider"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,31}$", var.wif_provider_id))
    error_message = "Provider ID must be 4-32 characters, start with letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev or prd)"
  type        = string
  default     = "dev"
}

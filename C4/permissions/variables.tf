# C4 Permissions Stack - Variables

# ============================================================================
# PROJECT SETTINGS
# ============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "iac-rattrapage-epitech"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Environment name (dev or prd)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "Environment must be 'dev' or 'prd'."
  }
}

# ============================================================================
# TEAM ACCESS
# ============================================================================

variable "professors" {
  description = "Map of professors with their email and GCP role"
  type = map(object({
    email = string
    role  = string
  }))
  default = {}
}

variable "students" {
  description = "Map of students with their email and GCP role"
  type = map(object({
    email = string
    role  = string
  }))
  default = {}
}

variable "service_accounts" {
  description = "Map of external service accounts with their email and role"
  type = map(object({
    email = string
    role  = string
  }))
  default = {}
}

# ============================================================================
# BILLING ACCESS
# ============================================================================

variable "billing_account_id" {
  description = "GCP Billing Account ID for billing viewer access"
  type        = string
  default     = ""
}

variable "billing_viewers" {
  description = "Set of emails to grant billing viewer access"
  type        = set(string)
  default     = []
}

# ============================================================================
# GITHUB ACCESS
# ============================================================================

variable "github_owner" {
  description = "GitHub repository owner (user or organization)"
  type        = string
  default     = "RayaneMemiche"
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
  default     = "infra-as-code"
}

variable "github_collaborators" {
  description = "Map of GitHub collaborators with their username and permission"
  type = map(object({
    username   = string
    permission = string  # pull, push, admin, maintain, triage
  }))
  default = {}
}

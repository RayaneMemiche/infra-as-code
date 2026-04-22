# Cloud SQL Database Module - Variables

# ============================================================================
# PROJECT SETTINGS
# ============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for the Cloud SQL instance"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prd)"
  type        = string

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "Environment must be 'dev' or 'prd'."
  }
}

# ============================================================================
# INSTANCE CONFIGURATION
# ============================================================================

variable "instance_name" {
  description = "Name of the Cloud SQL instance"
  type        = string
}

variable "database_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "POSTGRES_15"
}

variable "db_tier" {
  description = "Cloud SQL machine tier (db-f1-micro for dev, db-custom-1-3840 for prd)"
  type        = string
  default     = "db-f1-micro"
}

variable "disk_size" {
  description = "Initial disk size in GB"
  type        = number
  default     = 10
}

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================

variable "db_name" {
  description = "Name of the database to create"
  type        = string
}

variable "db_user" {
  description = "Database username"
  type        = string
}

# ============================================================================
# NETWORK CONFIGURATION
# ============================================================================

variable "network_id" {
  description = "VPC Network ID for private IP configuration"
  type        = string
}

variable "private_vpc_connection" {
  description = "Private VPC connection ID (from networking module)"
  type        = string
}

# ============================================================================
# IAM CONFIGURATION
# ============================================================================

variable "app_service_account_email" {
  description = "Email of the application service account to grant secret access"
  type        = string
  default     = ""
}

# ============================================================================
# LABELS
# ============================================================================

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

# C4 Final Project - Input Variables

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

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "europe-west1-b"
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
# NETWORKING
# ============================================================================

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "c4-vpc"
}

variable "subnet_cidr" {
  description = "CIDR range for the main subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR range for GKE pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR range for GKE services"
  type        = string
  default     = "10.2.0.0/20"
}

# ============================================================================
# GKE CLUSTER
# ============================================================================

variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "c4-cluster"
}

variable "gke_node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-2" # 2 vCPU, 8GB RAM - enough for 1 node
}

variable "gke_min_nodes" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "gke_max_nodes" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 5 # For testing autoscaling
}

variable "gke_initial_nodes" {
  description = "Initial number of nodes in the node pool"
  type        = number
  default     = 1
}

# ============================================================================
# DATABASE
# ============================================================================

variable "db_instance_name" {
  description = "Name of the Cloud SQL instance"
  type        = string
  default     = "c4-postgres"
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "taskmanager"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "taskmanager"
}

# ============================================================================
# WORKLOAD IDENTITY FEDERATION
# ============================================================================

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
}

variable "wif_pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-pool"
}

variable "wif_provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
  default     = "github-provider"
}

# ============================================================================
# APPLICATION
# ============================================================================

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "taskmanager"
}

variable "app_image" {
  description = "Container image for the application"
  type        = string
  default     = ""
}

variable "app_image_tag" {
  description = "Container image tag for the application"
  type        = string
  default     = "latest"
}

variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 2
}

# ============================================================================
# MONITORING
# ============================================================================

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================================================
# LABELS & TAGS
# ============================================================================

variable "labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    project    = "c4-final"
    managed-by = "terraform"
    course     = "epitech-iac"
  }
}

# ============================================================================
# TEAM ACCESS - MOVED TO SEPARATE STACK
# ============================================================================
# Team access variables are now in /C4/permissions/
# See /C4/permissions/README.md for usage

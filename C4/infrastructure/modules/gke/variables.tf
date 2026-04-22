# GKE Module - Variables

# ============================================================================
# REQUIRED VARIABLES
# ============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone for zonal cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary range for pods"
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary range for services"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "app_name" {
  description = "Application name for service accounts"
  type        = string
}

# ============================================================================
# CLUSTER CONFIGURATION
# ============================================================================

variable "master_cidr" {
  description = "CIDR block for GKE master (must be /28)"
  type        = string
  default     = "172.16.0.0/28"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/28$", var.master_cidr))
    error_message = "Master CIDR must be a /28 block."
  }
}

variable "release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "Release channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "deletion_protection" {
  description = "Enable deletion protection for the cluster"
  type        = bool
  default     = false
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint for the GKE master (true = no public access to control plane)"
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks authorized to access the GKE master"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks (dev only)"
    }
  ]
}

variable "use_preemptible_nodes" {
  description = "Use preemptible VMs for cost savings"
  type        = bool
  default     = true
}

# ============================================================================
# APPLICATION NODE POOL
# ============================================================================

variable "app_pool_machine_type" {
  description = "Machine type for application node pool"
  type        = string
  default     = "e2-medium"
}

variable "app_pool_min_nodes" {
  description = "Minimum nodes in application pool"
  type        = number
  default     = 1
}

variable "app_pool_max_nodes" {
  description = "Maximum nodes in application pool"
  type        = number
  default     = 3
}

variable "app_pool_initial_nodes" {
  description = "Initial nodes in application pool"
  type        = number
  default     = 1
}

variable "app_pool_disk_size" {
  description = "Disk size in GB for application nodes"
  type        = number
  default     = 50
}

# ============================================================================
# RUNNERS NODE POOL
# ============================================================================

variable "runners_pool_machine_type" {
  description = "Machine type for runners node pool"
  type        = string
  default     = "e2-medium"
}

variable "runners_pool_min_nodes" {
  description = "Minimum nodes in runners pool"
  type        = number
  default     = 0
}

variable "runners_pool_max_nodes" {
  description = "Maximum nodes in runners pool"
  type        = number
  default     = 2
}

variable "runners_pool_initial_nodes" {
  description = "Initial nodes in runners pool"
  type        = number
  default     = 0
}

variable "runners_pool_disk_size" {
  description = "Disk size in GB for runner nodes"
  type        = number
  default     = 50
}

# ============================================================================
# WORKLOAD IDENTITY
# ============================================================================

variable "app_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "default"
}

variable "runners_namespace" {
  description = "Kubernetes namespace for GitHub runners"
  type        = string
  default     = "runners"
}

# ============================================================================
# LABELS
# ============================================================================

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

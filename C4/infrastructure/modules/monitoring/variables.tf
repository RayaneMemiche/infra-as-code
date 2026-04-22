# Monitoring Module - Variables

# ============================================================================
# REQUIRED VARIABLES
# ============================================================================

variable "environment" {
  description = "Environment name (dev or prd)"
  type        = string

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "Environment must be 'dev' or 'prd'."
  }
}

variable "grafana_admin_password" {
  description = "Grafana admin password (sensitive)"
  type        = string
  sensitive   = true
}

# ============================================================================
# OPTIONAL VARIABLES
# ============================================================================

variable "namespace" {
  description = "Kubernetes namespace for monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Version of kube-prometheus-stack Helm chart"
  type        = string
  default     = "56.6.2"
}

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "15d"
}

variable "prometheus_storage_size" {
  description = "Prometheus persistent volume size"
  type        = string
  default     = "10Gi"
}

variable "alertmanager_storage_size" {
  description = "Alertmanager persistent volume size"
  type        = string
  default     = "2Gi"
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

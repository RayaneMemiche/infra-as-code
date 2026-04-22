# Networking Module - Output Values

# ============================================================================
# VPC OUTPUTS
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "vpc_self_link" {
  description = "Self-link of the VPC network"
  value       = google_compute_network.vpc.self_link
}

# ============================================================================
# SUBNET OUTPUTS
# ============================================================================

output "subnet_id" {
  description = "ID of the main subnet"
  value       = google_compute_subnetwork.main.id
}

output "subnet_name" {
  description = "Name of the main subnet"
  value       = google_compute_subnetwork.main.name
}

output "subnet_self_link" {
  description = "Self-link of the main subnet"
  value       = google_compute_subnetwork.main.self_link
}

output "subnet_cidr" {
  description = "CIDR range of the main subnet"
  value       = google_compute_subnetwork.main.ip_cidr_range
}

# ============================================================================
# SECONDARY RANGES (for GKE)
# ============================================================================

output "pods_range_name" {
  description = "Name of the secondary IP range for pods"
  value       = google_compute_subnetwork.main.secondary_ip_range[0].range_name
}

output "services_range_name" {
  description = "Name of the secondary IP range for services"
  value       = google_compute_subnetwork.main.secondary_ip_range[1].range_name
}

output "pods_cidr" {
  description = "CIDR range for GKE pods"
  value       = google_compute_subnetwork.main.secondary_ip_range[0].ip_cidr_range
}

output "services_cidr" {
  description = "CIDR range for GKE services"
  value       = google_compute_subnetwork.main.secondary_ip_range[1].ip_cidr_range
}

# ============================================================================
# NAT OUTPUTS
# ============================================================================

output "router_name" {
  description = "Name of the Cloud Router"
  value       = google_compute_router.router.name
}

output "nat_name" {
  description = "Name of the Cloud NAT"
  value       = google_compute_router_nat.nat.name
}

# ============================================================================
# PRIVATE SERVICE CONNECTION (for Cloud SQL)
# ============================================================================

output "private_vpc_connection" {
  description = "Private VPC connection for Cloud SQL"
  value       = google_service_networking_connection.private_vpc_connection.id
}

output "private_ip_range_name" {
  description = "Name of the private IP range for services"
  value       = google_compute_global_address.private_ip_range.name
}

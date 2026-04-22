# Networking Module - VPC, Subnets, NAT, Firewall
# Creates the network foundation for GKE and Cloud SQL

# ============================================================================
# VPC NETWORK
# ============================================================================

resource "google_compute_network" "vpc" {
  name                            = var.vpc_name
  project                         = var.project_id
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false

}

# ============================================================================
# SUBNETS
# ============================================================================

# Main subnet for GKE nodes
resource "google_compute_subnetwork" "main" {
  name                     = "${var.vpc_name}-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  # Secondary ranges for GKE pods and services
  secondary_ip_range {
    range_name    = "${var.vpc_name}-pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "${var.vpc_name}-services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ============================================================================
# CLOUD NAT (for egress from private GKE nodes)
# ============================================================================

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

# Cloud NAT configuration
resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  project                            = var.project_id
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  # Timeouts for NAT connections
  min_ports_per_vm                    = 64
  max_ports_per_vm                    = 4096
  enable_endpoint_independent_mapping = false

  tcp_established_idle_timeout_sec = 1200
  tcp_transitory_idle_timeout_sec  = 30
  udp_idle_timeout_sec             = 30
}

# ============================================================================
# FIREWALL RULES
# ============================================================================

# Allow internal communication within VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.subnet_cidr,
    var.pods_cidr,
    var.services_cidr
  ]

  priority = 1000
}

# Allow HTTP/HTTPS from internet (for Load Balancer health checks and ingress)
resource "google_compute_firewall" "allow_http_https" {
  name    = "${var.vpc_name}-allow-http-https"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]

  priority = 1000
}

# Allow GCP Health Checks (required for Load Balancer)
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.vpc_name}-allow-health-checks"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080", "10256"] # App port + kubelet health
  }

  # GCP Health Check IP ranges
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]

  target_tags = ["gke-node"]

  priority = 1000
}

# Allow SSH for debugging (restricted - can be tightened further)
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.vpc_name}-allow-ssh"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # IAP (Identity-Aware Proxy) IP range for secure SSH
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["ssh-enabled"]

  priority = 1000
}

# Deny all other ingress (implicit, but explicit for clarity)
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${var.vpc_name}-deny-all-ingress"
  project = var.project_id
  network = google_compute_network.vpc.name

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  priority = 65534
}

# ============================================================================
# PRIVATE SERVICE CONNECTION (for Cloud SQL)
# ============================================================================

# Reserve IP range for private services (Cloud SQL, etc.)
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.vpc_name}-private-ip-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

# Private service connection for Cloud SQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  deletion_policy = "ABANDON"
}

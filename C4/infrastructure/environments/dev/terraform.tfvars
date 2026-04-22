# C4 Final Project - Development Environment Variables

# Project Settings
project_id  = "fourth-outpost-479614-t4"
region      = "europe-west1"
zone        = "europe-west1-b"
environment = "dev"

# Networking
vpc_name      = "c4-vpc-dev"
subnet_cidr   = "10.0.0.0/20"
pods_cidr     = "10.1.0.0/16"
services_cidr = "10.2.0.0/20"

# GKE Cluster
gke_cluster_name      = "c4-cluster-dev"
gke_node_machine_type = "e2-medium"
gke_min_nodes         = 1
gke_max_nodes         = 5
gke_initial_nodes     = 1

# Database
db_instance_name = "c4-postgres-dev"
db_tier          = "db-f1-micro"
db_name          = "taskmanager"
db_user          = "taskmanager"

# Workload Identity Federation
github_repo     = "Jouzep/infra-as-code"
wif_pool_id     = "github-pool"
wif_provider_id = "github-provider"

# Application
app_name     = "taskmanager"
app_replicas = 2

# Labels
labels = {
  project     = "c4-final"
  environment = "dev"
  managed-by  = "terraform"
  course      = "epitech-iac"
}

# Monitoring
# NOTE: Set grafana_admin_password via environment variable or -var flag:
#   export TF_VAR_grafana_admin_password="your-secure-password"
#   OR
#   terraform apply -var="grafana_admin_password=your-secure-password"
# grafana_admin_password = "" # DO NOT commit passwords to git

# Team Access - MOVED TO SEPARATE STACK
# See /C4/permissions/ for team access management

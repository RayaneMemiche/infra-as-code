# C4 Final Project - Production Environment Variables

# Project Settings
project_id  = "fourth-outpost-479614-t4"
region      = "europe-west1"
zone        = "europe-west1-b"
environment = "prd"

# Networking
vpc_name      = "c4-vpc-prd"
subnet_cidr   = "10.10.0.0/20"
pods_cidr     = "10.11.0.0/16"
services_cidr = "10.12.0.0/20"

# GKE Cluster
gke_cluster_name      = "c4-cluster-prd"
gke_node_machine_type = "e2-medium"
gke_min_nodes         = 2
gke_max_nodes         = 5
gke_initial_nodes     = 2

# Database
db_instance_name = "c4-postgres-prd"
db_tier          = "db-g1-small"
db_name          = "taskmanager"
db_user          = "taskmanager"

# Workload Identity Federation
github_repo     = "Jouzep/infra-as-code"
wif_pool_id     = "github-pool"
wif_provider_id = "github-provider"

# Application
app_name     = "taskmanager"
app_replicas = 3

# Labels
labels = {
  project     = "c4-final"
  environment = "prd"
  managed-by  = "terraform"
  course      = "epitech-iac"
}

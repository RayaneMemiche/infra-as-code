# Infra-as-code — Project Overview

## Purpose
Infrastructure as Code for the C4 final project on Google Cloud Platform (GCP): enables APIs, Workload Identity Federation (WIF), networking (VPC/Subnet/NAT/Firewall), GKE, database (Cloud SQL), and app deployment via Helm.

## Tech Stack
- Terraform (providers: google, google-beta, kubernetes, helm)
- GCP (VPC, Cloud NAT, IAM, WIF, GKE, Cloud SQL planned)
- Helm charts (runners, task-manager-api)
- Kubernetes on GKE
- Node.js Task Manager API (demo app)

## Structure
- C4/infrastructure: main Terraform stack (providers/backend, modules, env vars)
  - terraform.tf (providers + GCS backend)
  - main.tf, variables.tf, outputs.tf
  - modules/: identity-federation, networking, gke, database (planned)
  - environments/dev/terraform.tfvars
  - helm/: charts for runners and task-manager-api
- C4/permissions: separate Terraform stack for IAM team permissions
  - terraform.tf, main.tf, variables.tf, outputs.tf
  - environments/dev/terraform.tfvars
- C4/docs: permissions diagram
- C4/scripts: deploy-local.sh, setup-secrets.sh (Helm and secrets helpers)
- task-manager-api: simple Node.js REST API with Dockerfile and minimal deps

## Environments
- dev (present) and prd placeholders (for Helm values and tfvars)

## Current Status (from documentation)
- Done: APIs, Workload Identity Federation, Networking
- Done (C4 README): GKE cluster + 3 node pools
- Next: Database (Cloud SQL), Load Balancer (HTTPS Ingress)

## Backends & Auth
- Terraform remote state: GCS bucket tfstate-fourth-outpost-479614-t4 (prefix c4/terraform/state)
- Auth:
  - Local: gcloud auth application-default login
  - CI/CD: Workload Identity Federation (OIDC) from GitHub Actions

## Notable Paths
- Infrastructure README: C4/infrastructure/README.md
- Permissions README: C4/permissions/README.md
- Helm chart (app): C4/infrastructure/helm/task-manager-api
- Local deploy helper: C4/scripts/deploy-local.sh
- Secrets setup helper: C4/scripts/setup-secrets.sh
- App (Node): task-manager-api

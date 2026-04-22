# C4 Infrastructure Stack

Stack Terraform pour l'infrastructure GCP (APIs, WIF, Networking, GKE, etc.).

## Architecture

```
C4/infrastructure/
├── terraform.tf                 → Provider + Backend GCS
├── main.tf                      → Orchestration des modules
├── variables.tf                 → Variables d'entrée
├── outputs.tf                   → Outputs
├── modules/
│   ├── identity-federation/     → WIF + Service Account
│   └── networking/              → VPC, Subnets, NAT, Firewall
└── environments/
    └── dev/terraform.tfvars     → Variables environnement dev
```

## Progression Implementation

| Phase | Module | Status | Resources |
|-------|--------|--------|-----------|
| 1.1 | Base Setup | ✅ Done | Backend GCS, Providers |
| 1.1 | APIs | ✅ Done | 11 GCP APIs enabled |
| 1.1 | Identity Federation | ✅ Done | WIF Pool, Provider, SA |
| 1.2 | Networking | ✅ Done | VPC, Subnet, NAT, Firewall |
| 1.3 | GKE | ✅ Done | Cluster, 3 Node Pools |
| 1.4 | Database | ✅ Done | Cloud SQL PostgreSQL |
| 1.5 | Load Balancer | ⏳ Planned | HTTPS Ingress |
| 6.3 | Monitoring | ✅ Done | Prometheus, Grafana, Alertmanager |

## Ressources Gérées

### ✅ Phase 1.1 - Foundation
- **11 APIs GCP** activées (compute, container, sqladmin, etc.)
- **Workload Identity Federation** pour GitHub Actions
- **Service Account Terraform** avec 11 rôles admin

### ✅ Phase 1.2 - Networking (NEW)
| Resource | Name | Description |
|----------|------|-------------|
| VPC Network | `c4-vpc-dev` | Réseau privé isolé |
| Subnet | `c4-vpc-dev-subnet` | `10.0.0.0/20` pour nodes GKE |
| Secondary Range (Pods) | `c4-vpc-dev-pods` | `10.1.0.0/16` |
| Secondary Range (Services) | `c4-vpc-dev-services` | `10.2.0.0/20` |
| Cloud Router | `c4-vpc-dev-router` | Pour Cloud NAT |
| Cloud NAT | `c4-vpc-dev-nat` | Egress pour nodes privés |
| Firewall: allow-internal | - | Traffic interne VPC |
| Firewall: allow-http-https | - | Ports 80/443 (tagged) |
| Firewall: allow-health-checks | - | Health checks GCP LB |
| Firewall: allow-ssh | - | SSH via IAP uniquement |
| Firewall: deny-all-ingress | - | Deny par défaut |
| Private Service Connection | - | Pour Cloud SQL private IP |

### ⏳ Phase 1.3 - GKE (Next)
- GKE Cluster avec Workload Identity
- Node Pool: runners (CI/CD)
- Node Pool: application
- Node Pool: monitoring
- Auto-scaling configuré

### ⏳ Phase 1.4-1.5 - Database & Load Balancer
- Cloud SQL PostgreSQL (private IP)
- Global Static IP
- HTTPS Load Balancer
- SSL Certificate

## Diagramme Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GCP Project                              │
│              fourth-outpost-479614-t4                        │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                 VPC: c4-vpc-dev                      │    │
│  │                                                      │    │
│  │  ┌────────────────────────────────────────────┐     │    │
│  │  │         Subnet: 10.0.0.0/20                │     │    │
│  │  │                                            │     │    │
│  │  │   Secondary Ranges:                        │     │    │
│  │  │   ├─ Pods:     10.1.0.0/16                │     │    │
│  │  │   └─ Services: 10.2.0.0/20                │     │    │
│  │  │                                            │     │    │
│  │  │   ⏳ GKE Cluster (Phase 1.3)              │     │    │
│  │  │   ⏳ Cloud SQL (Phase 1.4)                │     │    │
│  │  └────────────────────────────────────────────┘     │    │
│  │                                                      │    │
│  │  Cloud NAT ──► Internet (egress only)               │    │
│  │                                                      │    │
│  │  Firewall Rules:                                    │    │
│  │  ├─ ✅ allow-internal                               │    │
│  │  ├─ ✅ allow-http-https                             │    │
│  │  ├─ ✅ allow-health-checks                          │    │
│  │  ├─ ✅ allow-ssh (IAP)                              │    │
│  │  └─ ✅ deny-all-ingress                             │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────────────────────────┐                   │
│  │  Workload Identity Federation        │                   │
│  │  ├─ Pool: github-pool                │                   │
│  │  ├─ Provider: github-provider        │                   │
│  │  └─ SA: terraform-dev                │                   │
│  └──────────────────────────────────────┘                   │
│                           │                                  │
│                           ▼                                  │
│                    GitHub Actions                            │
│                 (yorennz/infra-as-code)                      │
└─────────────────────────────────────────────────────────────┘
```

## Commandes

### Quick Start

```bash
cd C4/infrastructure

# 1. Initialiser
terraform init

# 2. Voir les changements
terraform plan -var-file=environments/dev/terraform.tfvars

# 3. Appliquer
terraform apply -var-file=environments/dev/terraform.tfvars
```

### Commandes Utiles

| Action | Commande |
|--------|----------|
| Valider | `terraform validate` |
| Formater | `terraform fmt -recursive` |
| État | `terraform state list` |
| Outputs | `terraform output` |
| Détruire | `terraform destroy -var-file=environments/dev/terraform.tfvars` |

### Vérifier dans GCP Console

```bash
# VPC Network
gcloud compute networks list --project=fourth-outpost-479614-t4

# Subnets
gcloud compute networks subnets list --project=fourth-outpost-479614-t4

# Firewall Rules
gcloud compute firewall-rules list --project=fourth-outpost-479614-t4

# Cloud NAT
gcloud compute routers nats list --router=c4-vpc-dev-router --region=europe-west1

# WIF Pool
gcloud iam workload-identity-pools list --location=global

# Service Account
gcloud iam service-accounts list --project=fourth-outpost-479614-t4
```

## Variables

| Variable | Description | Dev Value |
|----------|-------------|-----------|
| `project_id` | GCP Project ID | `fourth-outpost-479614-t4` |
| `region` | GCP Region | `europe-west1` |
| `zone` | GCP Zone | `europe-west1-b` |
| `environment` | Environment | `dev` |
| `vpc_name` | VPC name | `c4-vpc-dev` |
| `subnet_cidr` | Subnet CIDR | `10.0.0.0/20` |
| `pods_cidr` | Pods CIDR | `10.1.0.0/16` |
| `services_cidr` | Services CIDR | `10.2.0.0/20` |
| `github_repo` | GitHub repo for WIF | `yorennz/infra-as-code` |

## Outputs

| Output | Description |
|--------|-------------|
| `wif_pool_name` | WIF Pool full name |
| `wif_provider_name` | WIF Provider full name |
| `terraform_service_account_email` | Terraform SA email |
| `workload_identity_provider` | WIF provider for GitHub Actions |
| `vpc_id` | VPC network ID |
| `vpc_name` | VPC network name |
| `subnet_id` | Subnet ID |
| `subnet_name` | Subnet name |
| `pods_range_name` | Secondary range name for pods |
| `services_range_name` | Secondary range name for services |
| `nat_name` | Cloud NAT name |

## Troubleshooting

### Erreur d'authentification

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project fourth-outpost-479614-t4
```

### State lock error

```bash
terraform force-unlock LOCK_ID
```

### Réinitialiser providers

```bash
rm -rf .terraform .terraform.lock.hcl
terraform init
```

## Workflow Git

```bash
# 1. Feature branch
git checkout -b feature/gke-cluster

# 2. Développer + valider
terraform fmt -recursive
terraform validate
terraform plan -var-file=environments/dev/terraform.tfvars

# 3. Commit + PR
git add . && git commit -m "feat(infra): add GKE cluster module"
git push origin feature/gke-cluster

# 4. Après merge → tag pour deploy
git checkout main && git pull
git tag -a v1.1.0 -m "Add networking module"
git push origin v1.1.0
```

## Monitoring Stack (Section 6.3)

Le stack de monitoring comprend Prometheus, Grafana, Alertmanager et les exporters, déployés via Terraform (`helm_release`).

### Architecture Monitoring

```
┌─────────────────────────────────────────────────────────────────┐
│                    Namespace: monitoring                         │
│                                                                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────┐    │
│  │  Prometheus  │   │   Grafana    │   │  Alertmanager    │    │
│  │   :9090      │◄──│    :3000     │   │     :9093        │    │
│  └──────┬───────┘   └──────────────┘   └──────────────────┘    │
│         │                                                        │
│         │ scrape /metrics                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  ServiceMonitors                                          │   │
│  │  ├─ kube-state-metrics (cluster state)                   │   │
│  │  ├─ node-exporter (node metrics)                         │   │
│  │  └─ task-manager-api (app metrics)                       │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Acceder aux Dashboards

#### Prerequis

```bash
# 1. Se connecter au cluster GKE
gcloud container clusters get-credentials c4-cluster-dev \
  --zone europe-west1-b \
  --project fourth-outpost-479614-t4

# 2. Verifier la connexion
kubectl cluster-info
```

#### Grafana (Dashboards & Visualisation)

```bash
# Ouvrir le port-forward vers Grafana
kubectl port-forward -n monitoring svc/c4-monitoring-dev-grafana 3000:80

# Puis ouvrir dans le navigateur: http://localhost:3000
```

**Credentials Grafana:**
```bash
# Username
admin

# Password (recuperer depuis le secret Kubernetes)
kubectl get secret -n monitoring c4-monitoring-dev-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode && echo
```

**Navigation dans Grafana:**
1. Menu hamburger (≡) en haut a gauche
2. Cliquer sur **Dashboards**
3. Dashboards disponibles:
   - `Kubernetes / Compute Resources / Cluster` - Vue globale du cluster
   - `Kubernetes / Compute Resources / Namespace (Pods)` - Metriques par namespace
   - `Kubernetes / Compute Resources / Pod` - Details par pod
   - `Node Exporter / Nodes` - Metriques systeme des nodes

#### Prometheus (Queries & Debug)

```bash
# Ouvrir le port-forward vers Prometheus
kubectl port-forward -n monitoring svc/c4-monitoring-dev-prometheus 9090:9090

# Puis ouvrir dans le navigateur: http://localhost:9090
```

**Queries utiles dans Prometheus:**
```promql
# CPU usage par pod dans task-manager
sum(rate(container_cpu_usage_seconds_total{namespace="task-manager"}[5m])) by (pod)

# Memory usage par pod
sum(container_memory_working_set_bytes{namespace="task-manager"}) by (pod)

# Requetes HTTP par seconde (si app deployee)
rate(http_requests_total{namespace="task-manager"}[5m])

# Latence 95e percentile
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```

#### Alertmanager (Alertes)

```bash
# Ouvrir le port-forward vers Alertmanager
kubectl port-forward -n monitoring svc/c4-monitoring-alertmanager 9093:9093

# Puis ouvrir dans le navigateur: http://localhost:9093
```

### Verifier le Status du Monitoring

```bash
# Lister tous les pods du monitoring
kubectl get pods -n monitoring

# Verifier les services
kubectl get svc -n monitoring

# Voir les logs Grafana
kubectl logs -n monitoring deployment/c4-monitoring-dev-grafana -c grafana

# Voir les logs Prometheus
kubectl logs -n monitoring statefulset/prometheus-c4-monitoring-prometheus

# Verifier les ServiceMonitors actifs
kubectl get servicemonitors -A

# Verifier les alertes Prometheus
kubectl get prometheusrules -n monitoring
```

### Alertes Configurees

| Alerte | Severite | Description |
|--------|----------|-------------|
| HighCPUUsage | warning | Pod utilise >90% CPU demande |
| HighMemoryUsage | warning | Pod utilise >90% memoire demandee |
| HPAMaxedOut | critical | HPA au max de replicas depuis 15min |
| PodCrashLooping | critical | Pod redémarre frequemment |
| PodNotReady | warning | Pod not ready depuis 10min |
| HighRequestLatency | warning | Latence P95 > 1s |
| HighErrorRate | critical | Taux d'erreur 5xx > 5% |
| RunnerPodHighCPU | warning | Runner GitHub utilise beaucoup de CPU |
| RunnerPodHighMemory | warning | Runner GitHub utilise >900MB RAM |

### Troubleshooting Monitoring

#### Grafana page vide / pas de dashboards

```bash
# Verifier que les ConfigMaps des dashboards existent
kubectl get configmaps -n monitoring -l grafana_dashboard=1

# Verifier les logs du sidecar dashboard
kubectl logs -n monitoring deployment/c4-monitoring-dev-grafana -c grafana-sc-dashboard

# Redemarrer Grafana si necessaire (attention aux ressources)
kubectl rollout restart deployment/c4-monitoring-dev-grafana -n monitoring
```

#### Prometheus ne scrape pas les metriques

```bash
# Verifier les targets dans Prometheus UI
# http://localhost:9090/targets (apres port-forward)

# Verifier que le ServiceMonitor existe
kubectl get servicemonitor -n task-manager

# Verifier les labels du service
kubectl get svc -n task-manager --show-labels
```

#### Impossible de se connecter

```bash
# Verifier que le pod est Running
kubectl get pods -n monitoring | grep grafana

# Verifier les events
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana

# Verifier le port-forward
# Si "connection refused", le pod n'est peut-etre pas ready
kubectl get pods -n monitoring -o wide
```

### Variables Terraform Monitoring

| Variable | Description | Valeur Dev |
|----------|-------------|------------|
| `grafana_admin_password` | Mot de passe admin Grafana | Via `TF_VAR_grafana_admin_password` |
| `prometheus_retention` | Duree retention metriques | `7d` (dev) / `30d` (prd) |
| `prometheus_storage_size` | Taille stockage Prometheus | `5Gi` (dev) / `50Gi` (prd) |

### Outputs Monitoring

| Output | Description |
|--------|-------------|
| `monitoring_namespace` | Namespace Kubernetes (`monitoring`) |
| `grafana_service` | Nom du service Grafana |
| `prometheus_service` | Nom du service Prometheus |
| `grafana_port_forward_command` | Commande port-forward Grafana |
| `prometheus_port_forward_command` | Commande port-forward Prometheus |

## Voir aussi

- [Permissions Stack](../permissions/README.md) - Gestion des acces equipe
- [C4 README Principal](../README.md) - Vue d'ensemble du projet
- [Permissions Diagram](../docs/PERMISSIONS-DIAGRAM.md) - Architecture des permissions

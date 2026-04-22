# C4 Final Project - Infrastructure as Code

Projet final Epitech IaC sur GCP avec **2 stacks Terraform séparées**.

## Progression

| Phase | Component | Status | Description |
|-------|-----------|--------|-------------|
| 1.1 | APIs + WIF | ✅ Done | 11 APIs, Workload Identity Federation |
| 1.2 | Networking | ✅ Done | VPC, Subnet, NAT, Firewall |
| 1.3 | GKE | ✅ Done | Kubernetes cluster + 3 node pools |
| 1.4 | Database | ✅ Done | Cloud SQL PostgreSQL |
| 1.5 | Load Balancer | ⏳ Planned | HTTPS Ingress |
| 2 | Helm Charts | ✅ Done | Runners + App + Monitoring charts |
| 3 | Application | ✅ Done | Task Manager REST API |
| 5 | Monitoring | ✅ Done | Prometheus + Grafana (module + helm chart) |

## Architecture

```
C4/
├── infrastructure/              ← Stack 1: INFRA
│   ├── terraform.tf             → Backend: tfstate/.../infrastructure/dev
│   ├── main.tf                  → APIs, WIF, Networking, GKE, (DB...)
│   ├── variables.tf
│   ├── outputs.tf
│   ├── modules/
│   │   ├── identity-federation/ → WIF + Service Account
│   │   ├── networking/          → VPC, Subnets, NAT, Firewall
│   │   ├── gke/                 → GKE Cluster + Node Pools
│   │   ├── database/            → Cloud SQL PostgreSQL
│   │   └── monitoring/          → Prometheus + Grafana
│   ├── helm/
│   │   ├── runners/             → Self-hosted GitHub Actions runners
│   │   ├── task-manager-api/    → Application chart
│   │   └── monitoring/          → Monitoring stack (values + dashboards)
│   └── environments/
│       └── dev/terraform.tfvars
│
├── permissions/                 ← Stack 2: PERMISSIONS
│   ├── terraform.tf             → Backend: tfstate/.../permissions/dev
│   ├── main.tf                  → IAM équipe (prof, étudiants, billing)
│   ├── variables.tf
│   ├── outputs.tf
│   └── environments/
│       └── dev/terraform.tfvars
│
├── load-testing/                 ← Load Testing (Locust)
│   └── locustfile.py             → Load test scenarios
│
├── docs/                        → Documentation
│   └── PERMISSIONS-DIAGRAM.md
│
└── .github/workflows/           → GitHub Actions CI/CD
    ├── terraform-validate.yml
    ├── terraform-plan.yml
    ├── terraform-apply.yml
    ├── terraform-destroy.yml
    └── test-wif-auth.yml
```

## Diagramme Architecture Actuel

```
┌─────────────────────────────────────────────────────────────────┐
│                        GCP Project                               │
│                 iac-rattrapage-epitech                         │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    VPC: c4-vpc-dev                         │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────┐     │  │
│  │  │            Subnet: 10.0.0.0/20                    │     │  │
│  │  │                                                   │     │  │
│  │  │   Secondary Ranges:                               │     │  │
│  │  │   ├─ Pods:     10.1.0.0/16                       │     │  │
│  │  │   └─ Services: 10.2.0.0/20                       │     │  │
│  │  │                                                   │     │  │
│  │  │   ✅ GKE Cluster: c4-cluster-dev                 │     │  │
│  │  │      ├─ Node Pool: application (1-3 nodes)       │     │  │
│  │  │      ├─ Node Pool: runners (0-2, tainted)        │     │  │
│  │  │      └─ Node Pool: monitoring (1, tainted)       │     │  │
│  │  │                                                   │     │  │
│  │  │   ✅ Cloud SQL PostgreSQL (private IP)            │     │  │
│  │  │                                                   │     │  │
│  │  │   ✅ Monitoring Stack:                            │     │  │
│  │  │      ├─ Prometheus (metrics collection)           │     │  │
│  │  │      ├─ Grafana (dashboards & alerts)             │     │  │
│  │  │      ├─ kube-state-metrics                        │     │  │
│  │  │      └─ node-exporter                             │     │  │
│  │  └──────────────────────────────────────────────────┘     │  │
│  │                                                            │  │
│  │  Cloud NAT ──────────────────────────► Internet (egress)  │  │
│  │                                                            │  │
│  │  Firewall Rules:                                          │  │
│  │  ├─ ✅ allow-internal (VPC traffic)                       │  │
│  │  ├─ ✅ allow-http-https (80/443)                          │  │
│  │  ├─ ✅ allow-health-checks (LB probes)                    │  │
│  │  ├─ ✅ allow-ssh (IAP only)                               │  │
│  │  └─ ✅ deny-all-ingress (default)                         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────┐  ┌────────────────────────────┐ │
│  │  Workload Identity Fed.    │  │  Team Permissions          │ │
│  │  ├─ Pool: github-pool      │  │  ├─ Prof: viewer + billing │ │
│  │  ├─ Provider: github-prov  │  │  └─ Students: editor       │ │
│  │  └─ SA: terraform-dev      │  │                            │ │
│  └────────────────────────────┘  └────────────────────────────┘ │
│               │                                                  │
│               ▼                                                  │
│        GitHub Actions (RayaneMemiche/infra-as-code)                   │
└─────────────────────────────────────────────────────────────────┘
```

## Pourquoi 2 Stacks ?

| Aspect | Infrastructure | Permissions |
|--------|---------------|-------------|
| **Responsabilité** | DevOps/Infra | Admin/Prof |
| **Fréquence** | Rare | Fréquente |
| **Impact** | Critique | Limité |
| **State** | Isolé | Isolé |

## Quick Start

### 1. Prérequis

```bash
# Installer Terraform
brew install terraform

# Installer gcloud
brew install --cask google-cloud-sdk

# Authentification
gcloud auth login
gcloud auth application-default login
gcloud config set project iac-rattrapage-epitech
```

### 2. Stack Infrastructure

```bash
cd C4/infrastructure
terraform init
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

### 3. Stack Permissions

```bash
cd C4/permissions
terraform init
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

## Ressources Déployées

### Stack Infrastructure

| Phase | Resources | Count |
|-------|-----------|-------|
| 1.1 | APIs GCP | 11 |
| 1.1 | WIF (Pool, Provider, SA, Bindings) | 15 |
| 1.2 | Networking (VPC, Subnet, NAT, Firewall) | 11 |
| 1.3 | GKE (Cluster, Node Pools, SAs, IAM) | 15 |
| **Total** | | **~52** |

**Détail:**
- ✅ 11 APIs GCP activées
- ✅ Workload Identity Federation (WIF)
- ✅ Service Account Terraform avec 11 rôles
- ✅ VPC Network + Subnet with secondary ranges
- ✅ Cloud Router + Cloud NAT
- ✅ 5 Firewall rules (internal, http/https, health-checks, ssh, deny-all)
- ✅ Private Service Connection (pour Cloud SQL)
- ✅ GKE Cluster avec 3 node pools (application, runners, monitoring)
- ✅ 2 Service Accounts GKE (app, runners) avec Workload Identity
- ✅ Cloud SQL PostgreSQL (private IP, automated backups)
- ✅ Monitoring stack (Prometheus + Grafana + dashboards)
- ⏳ Load Balancer (Phase 1.5)

### Stack Permissions

- ✅ Professor access (viewer)
- ✅ Student access (editor)
- ✅ Billing viewer pour prof

## Gestion des Accès Équipe

### Configuration actuelle

| Type | Nom | Email | Rôle |
|------|-----|-------|------|
| Prof | jjaouen | jeremie@jjaouen.com | viewer + billing |
| Étudiant | rayane | rayane.memiche@epitech.eu | editor |

### Ajouter un membre

1. Modifier `C4/permissions/environments/dev/terraform.tfvars`:

```hcl
students = {
  # Existants...

  nouveau = {
    email = "nouveau@example.com"
    role  = "roles/editor"
  }
}
```

2. Appliquer:

```bash
cd C4/permissions
terraform apply -var-file=environments/dev/terraform.tfvars
```

## Vérification des Ressources GCP

### Script de Vérification Complet

```bash
#!/bin/bash
# verify-all.sh - Vérifier toutes les ressources Terraform

PROJECT_ID="iac-rattrapage-epitech"
REGION="europe-west1"
ZONE="europe-west1-b"
VPC_NAME="c4-vpc-dev"
CLUSTER_NAME="c4-cluster-dev"

echo "=============================================="
echo "🔍 VÉRIFICATION COMPLÈTE DES RESSOURCES C4"
echo "=============================================="

# ==========================================
# 1. IDENTITY FEDERATION
# ==========================================
echo -e "\n\n========== 1. IDENTITY FEDERATION =========="

echo -e "\n🏊 1.1 Workload Identity Pool"
gcloud iam workload-identity-pools describe github-pool \
  --location=global \
  --project=$PROJECT_ID \
  --format="table(name,state)" 2>/dev/null && \
  echo "✅ Pool exists" || echo "❌ Pool not found"

echo -e "\n🔌 1.2 Workload Identity Provider"
gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool=github-pool \
  --location=global \
  --project=$PROJECT_ID \
  --format="table(name,state)" 2>/dev/null && \
  echo "✅ Provider exists" || echo "❌ Provider not found"

echo -e "\n👤 1.3 Terraform Service Account"
gcloud iam service-accounts describe \
  terraform-dev@${PROJECT_ID}.iam.gserviceaccount.com \
  --format="table(email,displayName)" 2>/dev/null && \
  echo "✅ SA exists" || echo "❌ SA not found"

echo -e "\n🔐 1.4 Terraform SA Roles"
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:terraform-dev@${PROJECT_ID}.iam.gserviceaccount.com" \
  --format="table(bindings.role)" 2>/dev/null

# ==========================================
# 2. NETWORKING
# ==========================================
echo -e "\n\n========== 2. NETWORKING =========="

echo -e "\n📡 2.1 VPC Network"
gcloud compute networks describe $VPC_NAME \
  --project=$PROJECT_ID \
  --format="table(name,routingConfig.routingMode)" 2>/dev/null && \
  echo "✅ VPC exists" || echo "❌ VPC not found"

echo -e "\n🔲 2.2 Subnet"
gcloud compute networks subnets describe ${VPC_NAME}-subnet \
  --region=$REGION \
  --project=$PROJECT_ID \
  --format="table(name,ipCidrRange,secondaryIpRanges[].rangeName)" 2>/dev/null && \
  echo "✅ Subnet exists" || echo "❌ Subnet not found"

echo -e "\n🔀 2.3 Cloud Router"
gcloud compute routers describe ${VPC_NAME}-router \
  --region=$REGION \
  --project=$PROJECT_ID \
  --format="table(name,bgp.asn)" 2>/dev/null && \
  echo "✅ Router exists" || echo "❌ Router not found"

echo -e "\n🌐 2.4 Cloud NAT"
gcloud compute routers nats describe ${VPC_NAME}-nat \
  --router=${VPC_NAME}-router \
  --region=$REGION \
  --project=$PROJECT_ID \
  --format="table(name,natIpAllocateOption)" 2>/dev/null && \
  echo "✅ NAT exists" || echo "❌ NAT not found"

echo -e "\n🔥 2.5 Firewall Rules"
for rule in "allow-internal" "allow-http-https" "allow-health-checks" "allow-ssh" "deny-all-ingress"; do
  gcloud compute firewall-rules describe ${VPC_NAME}-${rule} \
    --project=$PROJECT_ID \
    --format="value(name)" 2>/dev/null && \
    echo "  ✅ ${rule}" || echo "  ❌ ${rule} not found"
done

echo -e "\n🔗 2.6 Private Service Connection"
gcloud compute addresses describe ${VPC_NAME}-private-ip-range \
  --global \
  --project=$PROJECT_ID \
  --format="table(name,purpose)" 2>/dev/null && \
  echo "✅ Private IP range exists" || echo "❌ Private IP range not found"

# ==========================================
# 3. GKE
# ==========================================
echo -e "\n\n========== 3. GKE =========="

echo -e "\n☸️ 3.1 GKE Cluster"
gcloud container clusters describe $CLUSTER_NAME \
  --zone=$ZONE \
  --project=$PROJECT_ID \
  --format="table(name,status,currentMasterVersion)" 2>/dev/null && \
  echo "✅ Cluster exists" || echo "❌ Cluster not found"

echo -e "\n🖥️ 3.2 Node Pools"
gcloud container node-pools list \
  --cluster=$CLUSTER_NAME \
  --zone=$ZONE \
  --project=$PROJECT_ID \
  --format="table(name,config.machineType,autoscaling.minNodeCount,autoscaling.maxNodeCount,status)" 2>/dev/null

echo -e "\n👤 3.3 GKE Service Accounts"
for sa in "taskmanager-app-dev" "taskmanager-runners-dev"; do
  gcloud iam service-accounts describe ${sa}@${PROJECT_ID}.iam.gserviceaccount.com \
    --format="value(email)" 2>/dev/null && \
    echo "  ✅ ${sa}" || echo "  ❌ ${sa} not found"
done

echo -e "\n🔐 3.4 App SA Roles"
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:taskmanager-app-dev@${PROJECT_ID}.iam.gserviceaccount.com" \
  --format="value(bindings.role)" 2>/dev/null | while read role; do echo "  ✅ $role"; done

echo -e "\n🔐 3.5 Runners SA Roles"
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:taskmanager-runners-dev@${PROJECT_ID}.iam.gserviceaccount.com" \
  --format="value(bindings.role)" 2>/dev/null | while read role; do echo "  ✅ $role"; done

# ==========================================
# SUMMARY
# ==========================================
echo -e "\n\n========== RÉSUMÉ =========="
echo "WIF Pools: $(gcloud iam workload-identity-pools list --location=global --format='value(name)' --project=$PROJECT_ID 2>/dev/null | wc -l | tr -d ' ')"
echo "VPC Networks: $(gcloud compute networks list --filter="name:$VPC_NAME" --format='value(name)' --project=$PROJECT_ID 2>/dev/null | wc -l | tr -d ' ')"
echo "Firewall Rules: $(gcloud compute firewall-rules list --filter="network:$VPC_NAME" --format='value(name)' --project=$PROJECT_ID 2>/dev/null | wc -l | tr -d ' ')"
echo "GKE Clusters: $(gcloud container clusters list --filter="name:$CLUSTER_NAME" --format='value(name)' --project=$PROJECT_ID 2>/dev/null | wc -l | tr -d ' ')"
echo "GKE Node Pools: $(gcloud container node-pools list --cluster=$CLUSTER_NAME --zone=$ZONE --format='value(name)' --project=$PROJECT_ID 2>/dev/null | wc -l | tr -d ' ')"
echo "Service Accounts: $(gcloud iam service-accounts list --filter='email~terraform OR email~taskmanager' --format='value(email)' --project=$PROJECT_ID 2>/dev/null | wc -l | tr -d ' ')"

echo -e "\n=============================================="
echo "✅ VÉRIFICATION TERMINÉE"
echo "=============================================="
```

### Commandes par Module

#### 1. Identity Federation

```bash
# Workload Identity Pool
gcloud iam workload-identity-pools list --location=global --project=iac-rattrapage-epitech

# Workload Identity Provider
gcloud iam workload-identity-pools providers list \
  --workload-identity-pool=github-pool \
  --location=global \
  --project=iac-rattrapage-epitech

# Terraform Service Account
gcloud iam service-accounts describe \
  terraform-dev@iac-rattrapage-epitech.iam.gserviceaccount.com

# SA Roles
gcloud projects get-iam-policy iac-rattrapage-epitech \
  --flatten="bindings[].members" \
  --filter="bindings.members:terraform-dev@iac-rattrapage-epitech.iam.gserviceaccount.com" \
  --format="table(bindings.role)"

# WIF Binding on SA
gcloud iam service-accounts get-iam-policy \
  terraform-dev@iac-rattrapage-epitech.iam.gserviceaccount.com
```

#### 2. Networking

```bash
# VPC
gcloud compute networks describe c4-vpc-dev --project=iac-rattrapage-epitech

# Subnet avec secondary ranges
gcloud compute networks subnets describe c4-vpc-dev-subnet \
  --region=europe-west1 \
  --project=iac-rattrapage-epitech

# Cloud Router
gcloud compute routers describe c4-vpc-dev-router \
  --region=europe-west1 \
  --project=iac-rattrapage-epitech

# Cloud NAT
gcloud compute routers nats describe c4-vpc-dev-nat \
  --router=c4-vpc-dev-router \
  --region=europe-west1 \
  --project=iac-rattrapage-epitech

# Firewall Rules
gcloud compute firewall-rules list \
  --filter="network:c4-vpc-dev" \
  --project=iac-rattrapage-epitech \
  --format="table(name,direction,priority,allowed[].map().firewall_rule().list():label=ALLOW)"

# Private Service Connection
gcloud compute addresses describe c4-vpc-dev-private-ip-range \
  --global \
  --project=iac-rattrapage-epitech

# VPC Peering
gcloud services vpc-peerings list \
  --network=c4-vpc-dev \
  --project=iac-rattrapage-epitech
```

#### 3. GKE

```bash
# Cluster
gcloud container clusters describe c4-cluster-dev \
  --zone=europe-west1-b \
  --project=iac-rattrapage-epitech

# Node Pools
gcloud container node-pools list \
  --cluster=c4-cluster-dev \
  --zone=europe-west1-b \
  --project=iac-rattrapage-epitech

# Node Pool details (taints, autoscaling)
gcloud container node-pools describe c4-cluster-dev-runners \
  --cluster=c4-cluster-dev \
  --zone=europe-west1-b \
  --project=iac-rattrapage-epitech \
  --format="yaml(config.taints,autoscaling)"

# GKE Service Accounts
gcloud iam service-accounts list \
  --filter="email:taskmanager" \
  --project=iac-rattrapage-epitech

# App SA Roles
gcloud projects get-iam-policy iac-rattrapage-epitech \
  --flatten="bindings[].members" \
  --filter="bindings.members:taskmanager-app-dev@iac-rattrapage-epitech.iam.gserviceaccount.com" \
  --format="table(bindings.role)"

# Runners SA Roles
gcloud projects get-iam-policy iac-rattrapage-epitech \
  --flatten="bindings[].members" \
  --filter="bindings.members:taskmanager-runners-dev@iac-rattrapage-epitech.iam.gserviceaccount.com" \
  --format="table(bindings.role)"

# Workload Identity bindings
gcloud iam service-accounts get-iam-policy \
  taskmanager-app-dev@iac-rattrapage-epitech.iam.gserviceaccount.com

# Get kubectl credentials
gcloud container clusters get-credentials c4-cluster-dev \
  --zone=europe-west1-b \
  --project=iac-rattrapage-epitech

# Kubectl commands (after credentials)
kubectl get nodes -o wide
kubectl get nodes -l pool=application
kubectl get namespaces
```

#### 4. APIs

```bash
# APIs activées
gcloud services list --enabled --project=iac-rattrapage-epitech

# Vérifier une API spécifique
gcloud services list --enabled --filter="name:container.googleapis.com" --project=iac-rattrapage-epitech
```

#### 5. Permissions (Stack 2)

```bash
# Tous les IAM bindings
gcloud projects get-iam-policy iac-rattrapage-epitech \
  --flatten="bindings[].members" \
  --format="table(bindings.role, bindings.members)"

# Accès d'un membre spécifique
gcloud projects get-iam-policy iac-rattrapage-epitech \
  --flatten="bindings[].members" \
  --filter="bindings.members:jeremie@jjaouen.com" \
  --format="table(bindings.role)"
```

### Résumé des Ressources Attendues

| Module | Type | Count |
|--------|------|-------|
| **Identity Federation** | WIF Pool | 1 |
| | WIF Provider | 1 |
| | Service Account | 1 |
| | IAM Role Bindings | 11 |
| | WIF Binding | 1 |
| **Networking** | VPC | 1 |
| | Subnet | 1 |
| | Cloud Router | 1 |
| | Cloud NAT | 1 |
| | Firewall Rules | 5 |
| | Global Address | 1 |
| | VPC Peering | 1 |
| **GKE** | Cluster | 1 |
| | Node Pools | 3 |
| | Service Accounts | 2 |
| | IAM Role Bindings | 7 |
| | WIF Bindings | 2 |
| **Total** | | **~52** |

## Workflow Git

```bash
# 1. Feature branch
git checkout -b feature/ma-feature

# 2. Modifications + commit
terraform fmt -recursive
git add . && git commit -m "feat: description"

# 3. Push + PR
git push origin feature/ma-feature
# → GitHub Actions lance validate + plan

# 4. Après merge, tag pour déployer
git checkout main && git pull
git tag -a v1.0.0 -m "Release"
git push origin v1.0.0
# → GitHub Actions lance apply
```

## Troubleshooting

### Erreur d'authentification

```bash
gcloud auth revoke --all
gcloud auth login
gcloud auth application-default login
```

### Erreur de state lock

```bash
terraform force-unlock LOCK_ID
```

### Réinitialiser les providers

```bash
rm -rf .terraform
terraform init
```

## Informations Projet

| Élément | Valeur |
|---------|--------|
| **Project ID** | `iac-rattrapage-epitech` |
| **Region** | `europe-west1` |
| **Zone** | `europe-west1-b` |
| **State Bucket** | `tfstate-iac-rattrapage-epitech` |
| **GitHub Repo** | `RayaneMemiche/infra-as-code` |
| **VPC Name** | `c4-vpc-dev` |
| **Subnet CIDR** | `10.0.0.0/20` |
| **Pods CIDR** | `10.1.0.0/16` |
| **Services CIDR** | `10.2.0.0/20` |

## Documentation Détaillée

- [Infrastructure README](infrastructure/README.md) - Stack infrastructure détaillée
- [Permissions README](permissions/README.md) - Stack permissions détaillée
- [Permissions Diagram](docs/PERMISSIONS-DIAGRAM.md) - Architecture des permissions

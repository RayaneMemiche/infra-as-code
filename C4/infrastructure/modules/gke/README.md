# GKE Module

Ce module déploie un **cluster GKE privé** avec **Workload Identity**, plusieurs **node pools** dédiés, et la configuration de sécurité appropriée.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GKE Cluster: c4-cluster-dev                        │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐    │
│  │   Application Pool  │  │    Runners Pool    │  │   Monitoring Pool  │    │
│  │                     │  │                    │  │                    │    │
│  │  • Task Manager API │  │  • GitHub Actions  │  │  • Prometheus      │    │
│  │  • Frontend         │  │    Self-hosted     │  │  • Grafana         │    │
│  │  • Backend services │  │    Runners         │  │  • Alertmanager    │    │
│  │                     │  │                    │  │                    │    │
│  │  Autoscaling: 1-3   │  │  Autoscaling: 0-2  │  │  Fixed: 1 node     │    │
│  │  Machine: e2-medium │  │  Machine: e2-medium│  │  Machine: e2-small │    │
│  │  Preemptible: Yes   │  │  Preemptible: Yes  │  │  SSD Storage       │    │
│  │                     │  │                    │  │                    │    │
│  │  No taints          │  │  Taint: runner=true│  │  Taint: monitoring │    │
│  │  (default pool)     │  │  (dedicated)       │  │  (dedicated)       │    │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                        Workload Identity                              │   │
│  │                                                                       │   │
│  │   K8s ServiceAccount ──► GCP Service Account ──► IAM Roles           │   │
│  │   (in-cluster)          (via WIF)               (Cloud SQL, etc.)    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Features:                                                                   │
│  • Private nodes (no public IPs)                                            │
│  • VPC-native (uses alias IPs)                                              │
│  • Network Policy (Calico)                                                  │
│  • Managed Prometheus                                                        │
│  • Shielded GKE Nodes                                                       │
│  • Auto-repair & Auto-upgrade                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Pourquoi cette Architecture ?

### Private Cluster

```
┌─────────────────┐                    ┌─────────────────┐
│  Public Cluster │                    │ Private Cluster │
│                 │                    │                 │
│  Nodes have     │   vs               │  Nodes have     │
│  PUBLIC IPs     │                    │  PRIVATE IPs    │
│                 │                    │                 │
│  ❌ Exposed     │                    │  ✅ Isolated    │
└─────────────────┘                    └─────────────────┘
```

- **Nodes privés**: Pas d'IP publique sur les nodes → réduction de la surface d'attaque
- **Control plane public**: Permet l'accès depuis GitHub Actions (avec restriction par IP possible en prod)
- **Cloud NAT**: Les nodes peuvent accéder à Internet pour puller des images (via NAT configuré dans le module networking)

### Workload Identity

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   Kubernetes    │  Trust  │      GKE        │   IAM   │      GCP        │
│ ServiceAccount  │ ──────► │ Workload Identity│ ──────►│  Resources      │
│                 │         │     Pool        │         │                 │
│ app/taskmanager │         │ project.svc.id  │         │ Cloud SQL       │
│                 │         │ .goog           │         │ Secret Manager  │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

**Avantages:**
- ✅ Pas de JSON keys dans les pods
- ✅ Credentials rotées automatiquement
- ✅ Audit trail GCP complet
- ✅ Principe du moindre privilège

### Node Pools Séparés

| Pool | Usage | Raison |
|------|-------|--------|
| **application** | Workloads métier | Pool par défaut, autoscaling selon la charge |
| **runners** | GitHub Actions | Isolé avec taint, preemptible pour coût réduit |
| **monitoring** | Observability | SSD pour Prometheus, isolé des workloads |

## Ressources Terraform Créées

### 1. Cluster GKE

```hcl
resource "google_container_cluster" "main" {
  name     = "c4-cluster-dev"
  location = "europe-west1-b"

  private_cluster_config {
    enable_private_nodes    = true  # Nodes sans IP publique
    enable_private_endpoint = false # Control plane accessible publiquement
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  workload_identity_config {
    workload_pool = "project-id.svc.id.goog"
  }
}
```

### 2. Node Pools

```hcl
# Application Pool - Autoscaling 1-3 nodes
resource "google_container_node_pool" "application" {
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
  node_config {
    preemptible  = true
    machine_type = "e2-medium"
  }
}

# Runners Pool - Autoscaling 0-2 nodes (tainted)
resource "google_container_node_pool" "runners" {
  node_config {
    taint {
      key    = "runner"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}

# Monitoring Pool - Fixed 1 node (tainted, SSD)
resource "google_container_node_pool" "monitoring" {
  node_count = 1
  node_config {
    disk_type = "pd-ssd"
    taint {
      key    = "monitoring"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}
```

### 3. Service Accounts Workload Identity

```hcl
# SA pour l'application
resource "google_service_account" "app_workload" {
  account_id = "taskmanager-app-dev"
}

# SA pour les runners
resource "google_service_account" "runners_workload" {
  account_id = "taskmanager-runners-dev"
}

# Binding Workload Identity
resource "google_service_account_iam_member" "app_workload_identity" {
  role   = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:project.svc.id.goog[default/taskmanager]"
}
```

### 4. IAM Roles

| Service Account | Roles | Usage |
|----------------|-------|-------|
| `taskmanager-app-dev` | `cloudsql.client`, `secretmanager.secretAccessor`, `logging.logWriter`, `monitoring.metricWriter` | Application access |
| `taskmanager-runners-dev` | `artifactregistry.writer`, `storage.objectViewer`, `logging.logWriter` | CI/CD runners |

## Usage

### Variables Requises

```hcl
module "gke" {
  source = "./modules/gke"

  # Required
  project_id          = "fourth-outpost-479614-t4"
  region              = "europe-west1"
  zone                = "europe-west1-b"
  cluster_name        = "c4-cluster-dev"
  vpc_name            = "c4-vpc-dev"
  subnet_name         = "c4-vpc-dev-subnet"
  pods_range_name     = "c4-vpc-dev-pods"
  services_range_name = "c4-vpc-dev-services"
  environment         = "dev"
  app_name            = "taskmanager"

  # Optional - shown with defaults
  release_channel       = "REGULAR"
  use_preemptible_nodes = true
  deletion_protection   = false

  labels = {
    project     = "c4-final"
    environment = "dev"
  }
}
```

### Connexion au Cluster

```bash
# Obtenir les credentials
gcloud container clusters get-credentials c4-cluster-dev \
  --zone europe-west1-b \
  --project fourth-outpost-479614-t4

# Vérifier la connexion
kubectl get nodes
kubectl get namespaces
```

### K9s - Terminal UI pour Kubernetes

K9s est une interface terminal interactive pour gérer le cluster Kubernetes.

#### Installation

```bash
# macOS (Homebrew)
brew install k9s

# Linux (Homebrew)
brew install k9s

# Linux (snap)
sudo snap install k9s

# Linux (téléchargement direct)
curl -sS https://webinstall.dev/k9s | bash
```

#### Connexion et Lancement

```bash
# 1. Se connecter au cluster GKE (si pas déjà fait)
gcloud container clusters get-credentials c4-cluster-dev \
  --zone europe-west1-b \
  --project fourth-outpost-479614-t4

# 2. Lancer k9s
k9s

# Lancer directement dans un namespace spécifique
k9s -n ci-cd        # Pour voir les runners
k9s -n default      # Namespace par défaut
k9s -n monitoring   # Pour le monitoring
```

#### Raccourcis Clavier k9s

| Touche | Action |
|--------|--------|
| `:` | Ouvrir la commande (ex: `:pods`, `:deploy`, `:svc`, `:ns`) |
| `/` | Filtrer/Rechercher |
| `Enter` | Sélectionner/Entrer dans une ressource |
| `Esc` | Retour / Annuler |
| `d` | Describe (détails de la ressource) |
| `l` | Logs du pod |
| `s` | Shell dans le container |
| `e` | Éditer la ressource (YAML) |
| `ctrl+d` | Supprimer la ressource |
| `y` | Afficher le YAML |
| `0-9` | Changer de namespace favori |
| `q` | Quitter k9s |

#### Commandes Utiles dans k9s

```
:pods        # Lister tous les pods
:deploy      # Lister les deployments
:svc         # Lister les services
:ns          # Lister/changer de namespace
:nodes       # Voir les nodes du cluster
:hpa         # Voir les HorizontalPodAutoscalers
:secrets     # Voir les secrets
:cm          # Voir les ConfigMaps
:events      # Voir les événements du cluster
:ctx         # Changer de contexte (si plusieurs clusters)
```

#### Exemples d'Utilisation

```bash
# Voir les pods des runners GitHub Actions
k9s -n ci-cd
# Puis taper: /runners pour filtrer

# Voir les logs d'un runner
# 1. k9s -n ci-cd
# 2. Sélectionner le pod avec les flèches
# 3. Appuyer sur 'l' pour les logs

# Shell dans un runner (debugging)
# 1. k9s -n ci-cd
# 2. Sélectionner le pod
# 3. Appuyer sur 's' pour le shell
```

#### Configuration k9s (Optionnel)

Créer `~/.config/k9s/config.yaml` pour personnaliser:

```yaml
k9s:
  refreshRate: 2
  maxConnRetry: 5
  enableMouse: false
  headless: false
  logoless: false
  crumbsless: false
  readOnly: false
  noExitOnCtrlC: false
  ui:
    enableSkins: true
    skin: default
  logger:
    tail: 100
    buffer: 5000
    sinceSeconds: 60
  currentContext: gke_fourth-outpost-479614-t4_europe-west1-b_c4-cluster-dev
  currentCluster: gke_fourth-outpost-479614-t4_europe-west1-b_c4-cluster-dev
```

### Configuration Workload Identity

Pour utiliser Workload Identity dans vos déploiements:

```yaml
# 1. Créer un ServiceAccount Kubernetes avec l'annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: taskmanager
  namespace: default
  annotations:
    iam.gke.io/gcp-service-account: taskmanager-app-dev@fourth-outpost-479614-t4.iam.gserviceaccount.com

---
# 2. Utiliser ce ServiceAccount dans le Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: taskmanager
spec:
  template:
    spec:
      serviceAccountName: taskmanager  # Référence au SA avec Workload Identity
      containers:
        - name: app
          image: gcr.io/project/taskmanager:latest
```

### Déployer sur Runners Pool (avec toleration)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-runner
  namespace: runners
spec:
  template:
    spec:
      tolerations:
        - key: "runner"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
      nodeSelector:
        pool: runners
      containers:
        - name: runner
          image: myrunner:latest
```

### Déployer sur Monitoring Pool (avec toleration)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  template:
    spec:
      tolerations:
        - key: "monitoring"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
      nodeSelector:
        pool: monitoring
      containers:
        - name: prometheus
          image: prom/prometheus:latest
```

## Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_id` | GCP Project ID | - | Yes |
| `region` | GCP Region | - | Yes |
| `zone` | GCP Zone | - | Yes |
| `cluster_name` | Cluster name | - | Yes |
| `vpc_name` | VPC network name | - | Yes |
| `subnet_name` | Subnet name | - | Yes |
| `pods_range_name` | Secondary range for pods | - | Yes |
| `services_range_name` | Secondary range for services | - | Yes |
| `environment` | Environment (dev/prod) | - | Yes |
| `app_name` | Application name | - | Yes |
| `master_cidr` | Master CIDR (/28) | `172.16.0.0/28` | No |
| `release_channel` | GKE release channel | `REGULAR` | No |
| `deletion_protection` | Enable deletion protection | `false` | No |
| `use_preemptible_nodes` | Use preemptible VMs | `true` | No |
| `app_pool_machine_type` | App pool machine type | `e2-medium` | No |
| `app_pool_min_nodes` | App pool min nodes | `1` | No |
| `app_pool_max_nodes` | App pool max nodes | `3` | No |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_id` | Cluster unique ID |
| `cluster_name` | Cluster name |
| `cluster_endpoint` | Control plane endpoint (sensitive) |
| `cluster_ca_certificate` | CA certificate (sensitive) |
| `application_pool_name` | Application node pool name |
| `runners_pool_name` | Runners node pool name |
| `monitoring_pool_name` | Monitoring node pool name |
| `workload_identity_pool` | Workload Identity pool |
| `app_service_account_email` | App SA email |
| `runners_service_account_email` | Runners SA email |
| `gcloud_get_credentials_command` | Command to get kubectl credentials |

## Vérification des Ressources

### Script de Vérification Complet

```bash
#!/bin/bash
# verify-gke.sh - Verify all GKE resources created by Terraform

PROJECT_ID="fourth-outpost-479614-t4"
CLUSTER_NAME="c4-cluster-dev"
ZONE="europe-west1-b"
APP_SA="taskmanager-app-dev@${PROJECT_ID}.iam.gserviceaccount.com"
RUNNERS_SA="taskmanager-runners-dev@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=========================================="
echo "🔍 Vérification des ressources GKE"
echo "=========================================="

# 1. GKE Cluster
echo -e "\n☸️ 1. GKE Cluster"
gcloud container clusters describe $CLUSTER_NAME \
  --zone=$ZONE \
  --project=$PROJECT_ID \
  --format="table(name,status,currentMasterVersion,endpoint)" 2>/dev/null && \
  echo "✅ Cluster exists" || echo "❌ Cluster not found"

# 2. Cluster Configuration
echo -e "\n⚙️ 2. Cluster Configuration"
gcloud container clusters describe $CLUSTER_NAME \
  --zone=$ZONE \
  --project=$PROJECT_ID \
  --format="yaml(privateClusterConfig,workloadIdentityConfig,addonsConfig.networkPolicyConfig)" 2>/dev/null

# 3. Node Pools
echo -e "\n🖥️ 3. Node Pools"
POOLS=$(gcloud container node-pools list \
  --cluster=$CLUSTER_NAME \
  --zone=$ZONE \
  --project=$PROJECT_ID \
  --format="value(name)" 2>/dev/null)

if [ -n "$POOLS" ]; then
  echo "Node pools found:"
  gcloud container node-pools list \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --format="table(name,config.machineType,autoscaling.minNodeCount,autoscaling.maxNodeCount,status)"

  POOL_COUNT=$(echo "$POOLS" | wc -l | tr -d ' ')
  echo "Total: $POOL_COUNT node pools"

  # Check for expected pools
  for pool in "application" "runners" "monitoring"; do
    if echo "$POOLS" | grep -q "$pool"; then
      echo "  ✅ ${CLUSTER_NAME}-${pool} pool exists"
    else
      echo "  ❌ ${CLUSTER_NAME}-${pool} pool not found"
    fi
  done
else
  echo "❌ No node pools found"
fi

# 4. Node Pool Details
echo -e "\n📊 4. Node Pool Details"
for pool in "${CLUSTER_NAME}-application" "${CLUSTER_NAME}-runners" "${CLUSTER_NAME}-monitoring"; do
  echo -e "\n--- $pool ---"
  gcloud container node-pools describe $pool \
    --cluster=$CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID \
    --format="yaml(config.machineType,config.diskSizeGb,config.preemptible,config.taints,management)" 2>/dev/null || echo "Pool not found"
done

# 5. Application Service Account
echo -e "\n👤 5. Application Service Account"
gcloud iam service-accounts describe $APP_SA \
  --project=$PROJECT_ID \
  --format="table(email,displayName)" 2>/dev/null && \
  echo "✅ App SA exists" || echo "❌ App SA not found"

# 6. Runners Service Account
echo -e "\n👤 6. Runners Service Account"
gcloud iam service-accounts describe $RUNNERS_SA \
  --project=$PROJECT_ID \
  --format="table(email,displayName)" 2>/dev/null && \
  echo "✅ Runners SA exists" || echo "❌ Runners SA not found"

# 7. Service Account IAM Roles
echo -e "\n🔐 7. Service Account IAM Roles"
echo "App SA roles:"
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$APP_SA" \
  --format="value(bindings.role)" 2>/dev/null | while read role; do echo "  ✅ $role"; done

echo -e "\nRunners SA roles:"
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$RUNNERS_SA" \
  --format="value(bindings.role)" 2>/dev/null | while read role; do echo "  ✅ $role"; done

# 8. Workload Identity Bindings
echo -e "\n🔗 8. Workload Identity Bindings"
echo "App SA WIF binding:"
gcloud iam service-accounts get-iam-policy $APP_SA \
  --project=$PROJECT_ID \
  --format="table(bindings.role,bindings.members)" 2>/dev/null

echo -e "\nRunners SA WIF binding:"
gcloud iam service-accounts get-iam-policy $RUNNERS_SA \
  --project=$PROJECT_ID \
  --format="table(bindings.role,bindings.members)" 2>/dev/null

# 9. Cluster Nodes (if cluster is running)
echo -e "\n🖥️ 9. Cluster Nodes"
gcloud container clusters get-credentials $CLUSTER_NAME \
  --zone=$ZONE \
  --project=$PROJECT_ID 2>/dev/null && \
kubectl get nodes -o wide 2>/dev/null || echo "Cannot connect to cluster (expected if not deployed)"

echo -e "\n=========================================="
echo "✅ Vérification terminée"
echo "=========================================="
```

### Commandes Individuelles

#### GKE Cluster
```bash
# Lister les clusters
gcloud container clusters list \
  --project=fourth-outpost-479614-t4

# Détails du cluster
gcloud container clusters describe c4-cluster-dev \
  --zone=europe-west1-b \
  --project=fourth-outpost-479614-t4

# Configuration Workload Identity
gcloud container clusters describe c4-cluster-dev \
  --zone=europe-west1-b \
  --project=fourth-outpost-479614-t4 \
  --format="yaml(workloadIdentityConfig)"

# Configuration Private Cluster
gcloud container clusters describe c4-cluster-dev \
  --zone=europe-west1-b \
  --project=fourth-outpost-479614-t4 \
  --format="yaml(privateClusterConfig)"
```

#### Node Pools
```bash
# Lister les node pools
gcloud container node-pools list \
  --cluster=c4-cluster-dev \
  --zone=europe-west1-b \
  --project=fourth-outpost-479614-t4

# Détails d'un node pool spécifique
gcloud container node-pools describe c4-cluster-dev-application \
  --cluster=c4-cluster-dev \
  --zone=europe-west1-b \
  --project=fourth-outpost-479614-t4

# Vérifier les taints sur runners pool
gcloud container node-pools describe c4-cluster-dev-runners \
  --cluster=c4-cluster-dev \
  --zone=europe-west1-b \
  --project=fourth-outpost-479614-t4 \
  --format="yaml(config.taints)"
```

#### Service Accounts
```bash
# Lister les SAs pour l'application
gcloud iam service-accounts list \
  --filter="email:taskmanager" \
  --project=fourth-outpost-479614-t4

# Détails du SA application
gcloud iam service-accounts describe \
  taskmanager-app-dev@fourth-outpost-479614-t4.iam.gserviceaccount.com

# Détails du SA runners
gcloud iam service-accounts describe \
  taskmanager-runners-dev@fourth-outpost-479614-t4.iam.gserviceaccount.com
```

#### IAM Roles
```bash
# Rôles du SA application
gcloud projects get-iam-policy fourth-outpost-479614-t4 \
  --flatten="bindings[].members" \
  --filter="bindings.members:taskmanager-app-dev@fourth-outpost-479614-t4.iam.gserviceaccount.com" \
  --format="table(bindings.role)"

# Rôles du SA runners
gcloud projects get-iam-policy fourth-outpost-479614-t4 \
  --flatten="bindings[].members" \
  --filter="bindings.members:taskmanager-runners-dev@fourth-outpost-479614-t4.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

#### Workload Identity Bindings
```bash
# Vérifier WIF binding sur SA application
gcloud iam service-accounts get-iam-policy \
  taskmanager-app-dev@fourth-outpost-479614-t4.iam.gserviceaccount.com

# Vérifier WIF binding sur SA runners
gcloud iam service-accounts get-iam-policy \
  taskmanager-runners-dev@fourth-outpost-479614-t4.iam.gserviceaccount.com
```

#### Kubectl (après déploiement)
```bash
# Obtenir les credentials
gcloud container clusters get-credentials c4-cluster-dev \
  --zone=europe-west1-b \
  --project=fourth-outpost-479614-t4

# Vérifier les nodes
kubectl get nodes -o wide

# Vérifier les node pools par label
kubectl get nodes -l pool=application
kubectl get nodes -l pool=runners
kubectl get nodes -l pool=monitoring

# Vérifier les namespaces
kubectl get namespaces
```

### Résumé des Ressources Attendues

```bash
# Commande rapide pour compter les ressources
PROJECT_ID="fourth-outpost-479614-t4"
CLUSTER="c4-cluster-dev"
ZONE="europe-west1-b"

echo "=== GKE Resources Count ==="
echo "Clusters: $(gcloud container clusters list --filter="name:$CLUSTER" --format='value(name)' --project=$PROJECT_ID | wc -l)"
echo "Node Pools: $(gcloud container node-pools list --cluster=$CLUSTER --zone=$ZONE --format='value(name)' --project=$PROJECT_ID 2>/dev/null | wc -l)"
echo "Service Accounts: $(gcloud iam service-accounts list --filter='email:taskmanager' --format='value(email)' --project=$PROJECT_ID | wc -l)"
echo "App SA Roles: $(gcloud projects get-iam-policy $PROJECT_ID --flatten='bindings[].members' --filter='bindings.members:taskmanager-app-dev' --format='value(bindings.role)' | wc -l)"
echo "Runners SA Roles: $(gcloud projects get-iam-policy $PROJECT_ID --flatten='bindings[].members' --filter='bindings.members:taskmanager-runners-dev' --format='value(bindings.role)' | wc -l)"
```

**Ressources attendues:**
| Type | Count | Details |
|------|-------|---------|
| GKE Cluster | 1 | c4-cluster-dev |
| Node Pools | 3 | application, runners, monitoring |
| Service Accounts | 2 | taskmanager-app-dev, taskmanager-runners-dev |
| App SA IAM Roles | 4 | cloudsql.client, secretmanager.secretAccessor, logging, monitoring |
| Runners SA IAM Roles | 3 | artifactregistry.writer, storage.objectViewer, logging |
| WIF Bindings | 2 | One per SA |
| **Total** | **~15** | (excluding nodes) |

## Sécurité

### Fonctionnalités de Sécurité Activées

- ✅ **Private Nodes**: Nodes sans IP publique
- ✅ **Shielded Nodes**: Secure boot + integrity monitoring
- ✅ **Workload Identity**: Pas de JSON keys dans les pods
- ✅ **Network Policy**: Calico pour isolation réseau
- ✅ **Auto-repair**: Nodes défectueux remplacés automatiquement
- ✅ **Auto-upgrade**: Patches de sécurité appliqués automatiquement
- ✅ **Master Authorized Networks**: Contrôle d'accès au control plane

### Recommandations Production

Pour un environnement de production, considérez:

1. **Private Endpoint**: `enable_private_endpoint = true` avec bastion
2. **Master Authorized Networks**: Restreindre à des IPs spécifiques
3. **Binary Authorization**: Validation des images container
4. **Pod Security Policies**: Restrictions sur les capabilities
5. **Deletion Protection**: `deletion_protection = true`

## Coût Estimé (Dev)

| Resource | Specification | ~Coût/mois |
|----------|---------------|------------|
| GKE Management | Free tier | $0 |
| Application Pool | 1x e2-medium preemptible | ~$15 |
| Runners Pool | 0-2x e2-medium preemptible | ~$0-30 |
| Monitoring Pool | 1x e2-small preemptible | ~$5 |
| **Total estimé** | | **~$20-50/mois** |

*Note: Prix approximatifs, utilisez le [GCP Pricing Calculator](https://cloud.google.com/products/calculator) pour des estimations précises.*

## Troubleshooting

### Erreur: "Unable to connect to cluster"

```bash
# Réinitialiser les credentials
gcloud container clusters get-credentials c4-cluster-dev \
  --zone europe-west1-b

# Vérifier le contexte kubectl
kubectl config current-context
```

### Erreur: "Workload Identity not working"

1. Vérifier l'annotation sur le ServiceAccount K8s
2. Vérifier le binding IAM sur le SA GCP
3. Tester avec:

```bash
kubectl run -it --rm test-wi \
  --image=google/cloud-sdk:slim \
  --serviceaccount=taskmanager \
  -- gcloud auth list
```

### Erreur: "Pods pending on tainted nodes"

Ajouter les tolerations appropriées:

```yaml
tolerations:
  - key: "runner"  # ou "monitoring"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
```

## Références

- [GKE Private Clusters](https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity)
- [Node Pools](https://cloud.google.com/kubernetes-engine/docs/concepts/node-pools)
- [GKE Security](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)

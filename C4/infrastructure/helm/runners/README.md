# GitHub Actions Runners Helm Chart

Ce Helm chart déploie des **runners GitHub Actions auto-hébergés** sur GKE avec **auto-registration**, **ephemeral mode**, et **autoscaling**.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        GitHub Actions Self-Hosted Runners                    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                         GitHub Actions                                  │ │
│  │                                                                         │ │
│  │   Workflow (.github/workflows/*.yaml)                                   │ │
│  │   └── runs-on: [self-hosted, gke, dev]                                 │ │
│  │                      │                                                  │ │
│  └──────────────────────┼──────────────────────────────────────────────────┘ │
│                         │ OIDC Token                                         │
│                         ▼                                                    │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                       GKE Cluster                                       │ │
│  │                                                                         │ │
│  │   Namespace: ci-cd                                                      │ │
│  │   ┌──────────────────────────────────────────────────────────────────┐ │ │
│  │   │                    Runners Deployment                             │ │ │
│  │   │                                                                   │ │ │
│  │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │ │ │
│  │   │  │   Runner    │  │   Runner    │  │   Runner    │  ... (HPA)    │ │ │
│  │   │  │   Pod #1    │  │   Pod #2    │  │   Pod #3    │               │ │ │
│  │   │  │             │  │             │  │             │               │ │ │
│  │   │  │ myoung34/   │  │ myoung34/   │  │ myoung34/   │               │ │ │
│  │   │  │ github-     │  │ github-     │  │ github-     │               │ │ │
│  │   │  │ runner      │  │ runner      │  │ runner      │               │ │ │
│  │   │  │             │  │             │  │             │               │ │ │
│  │   │  │ Labels:     │  │ Labels:     │  │ Labels:     │               │ │ │
│  │   │  │ self-hosted │  │ self-hosted │  │ self-hosted │               │ │ │
│  │   │  │ linux, x64  │  │ linux, x64  │  │ linux, x64  │               │ │ │
│  │   │  │ gke, dev    │  │ gke, dev    │  │ gke, dev    │               │ │ │
│  │   │  └─────────────┘  └─────────────┘  └─────────────┘               │ │ │
│  │   │                                                                   │ │ │
│  │   │  ┌─────────────────────────────────────────────────────────────┐ │ │ │
│  │   │  │ Secret: runners-github-secret                               │ │ │ │
│  │   │  │ • github-url: https://github.com/org/repo                   │ │ │ │
│  │   │  │ • access-token: ghp_xxxx (PAT)                              │ │ │ │
│  │   │  └─────────────────────────────────────────────────────────────┘ │ │ │
│  │   └──────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                         │ │
│  │   HPA (Horizontal Pod Autoscaler)                                       │ │
│  │   • Min replicas: 1 (dev) / 2 (prd)                                    │ │
│  │   • Max replicas: 3 (dev) / 10 (prd)                                   │ │
│  │   • Scale on: CPU 70%, Memory 80%                                      │ │
│  │                                                                         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Pourquoi cette Architecture ?

### Runners Auto-Hébergés vs GitHub-Hosted

```
┌─────────────────────────┐                ┌─────────────────────────┐
│   GitHub-Hosted         │                │   Self-Hosted (GKE)     │
│                         │                │                         │
│  ✅ Zero maintenance    │   vs           │  ✅ Accès VPC privé     │
│  ✅ Toujours disponible │                │  ✅ Contrôle total      │
│  ❌ Pas d'accès VPC     │                │  ✅ Coût prévisible     │
│  ❌ Coût par minute     │                │  ✅ Cache persistant    │
│  ❌ Ressources limitées │                │  ✅ Custom tools        │
└─────────────────────────┘                └─────────────────────────┘
```

**Avantages self-hosted pour C4:**
- ✅ Accès direct au cluster GKE et Cloud SQL
- ✅ Workload Identity pour auth sans credentials
- ✅ Coût fixe avec preemptible nodes
- ✅ Performance améliorée avec cache Docker

### Mode Éphémère

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Runner Ephemeral Lifecycle                       │
│                                                                      │
│   ┌──────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│   │ Pod  │───►│ Register │───►│ Run Job  │───►│ Unregister│         │
│   │ Start│    │ to GitHub│    │ (1 job)  │    │ & Exit   │         │
│   └──────┘    └──────────┘    └──────────┘    └──────────┘         │
│                                                      │               │
│                                                      ▼               │
│                                              ┌──────────────┐       │
│                                              │ K8s creates  │       │
│                                              │ new pod      │       │
│                                              └──────────────┘       │
│                                                                      │
│   Benefits:                                                          │
│   • Clean environment for each job                                   │
│   • No cross-job contamination                                       │
│   • Automatic cleanup on failure                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Image myoung34/github-runner

| Feature | Description |
|---------|-------------|
| **Auto-registration** | S'enregistre automatiquement avec PAT ou token |
| **Auto-unregister** | Se désenregistre proprement à l'arrêt |
| **Labels dynamiques** | Labels configurables via env vars |
| **Ephemeral support** | Mode éphémère natif |
| **DinD support** | Docker-in-Docker pour build d'images |

## Ressources Kubernetes Créées

### 1. Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: runners-github-actions-runners
  namespace: ci-cd
spec:
  replicas: 1  # Managed by HPA
  template:
    spec:
      containers:
        - name: runner
          image: myoung34/github-runner:latest
          env:
            - name: REPO_URL
              valueFrom:
                secretKeyRef:
                  name: runners-github-actions-runners-github
                  key: github-url
            - name: ACCESS_TOKEN
              valueFrom:
                secretKeyRef:
                  name: runners-github-actions-runners-github
                  key: access-token
            - name: LABELS
              value: "self-hosted,linux,x64,gke,dev"
            - name: EPHEMERAL
              value: "true"
```

### 2. Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: runners-github-actions-runners-github
type: Opaque
stringData:
  github-url: "https://github.com/org/repo"
  access-token: "ghp_xxxxxxxxxxxx"  # PAT with repo scope
```

### 3. HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: runners-github-actions-runners
spec:
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### 4. ServiceAccount & RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: runners-github-actions-runners
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: runners-github-actions-runners
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/exec", "pods/log", "secrets"]
    verbs: ["get", "list", "watch", "create", "delete"]
```

## Usage

### Prérequis

1. **GKE Cluster** déployé et accessible
2. **Personal Access Token (PAT)** avec scope `repo` (ou `admin:org` pour org-level)
3. **Helm 3.x** installé
4. **kubectl** configuré pour le cluster

### Créer un PAT GitHub

```bash
# Via GitHub CLI
gh auth login
# Puis aller sur: https://github.com/settings/tokens/new
# Scopes requis:
#   - repo (Full control of private repositories)
#   - Pour org-level: admin:org
```

### Déploiement Dev

```bash
# Connexion au cluster
gcloud container clusters get-credentials c4-cluster-dev \
  --zone europe-west1-b \
  --project iac-rattrapage-epitech

# Déploiement
helm install runners ./C4/infrastructure/helm/runners \
  -f ./C4/infrastructure/helm/runners/values-dev.yaml \
  --set github.url=https://github.com/YOUR_ORG/YOUR_REPO \
  --set github.accessToken=ghp_YOUR_PAT_TOKEN \
  --namespace ci-cd \
  --create-namespace
```

### Déploiement Production

```bash
helm install runners ./C4/infrastructure/helm/runners \
  -f ./C4/infrastructure/helm/runners/values-prd.yaml \
  --set github.url=https://github.com/YOUR_ORG/YOUR_REPO \
  --set github.accessToken=ghp_YOUR_PAT_TOKEN \
  --namespace ci-cd \
  --create-namespace
```

### Mise à Jour

```bash
helm upgrade runners ./C4/infrastructure/helm/runners \
  -f ./C4/infrastructure/helm/runners/values-dev.yaml \
  --set github.url=https://github.com/YOUR_ORG/YOUR_REPO \
  --set github.accessToken=ghp_YOUR_PAT_TOKEN \
  --namespace ci-cd
```

### Suppression

```bash
helm uninstall runners --namespace ci-cd
```

## Utilisation dans les Workflows

### Workflow Basique

```yaml
name: CI Pipeline
on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, gke, dev]  # Utilise les runners GKE dev
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: |
          echo "Running on self-hosted GKE runner!"
          make build
```

### Workflow avec Labels Spécifiques

```yaml
jobs:
  # Job sur runner dev
  test-dev:
    runs-on: [self-hosted, gke, dev]
    steps:
      - run: echo "Running on dev runner"

  # Job sur runner production (si déployé)
  deploy-prod:
    runs-on: [self-hosted, gke, prd]
    needs: test-dev
    steps:
      - run: echo "Running on prod runner"
```

### Workflow avec Docker Build

```yaml
jobs:
  build-image:
    runs-on: [self-hosted, gke, dev]
    steps:
      - uses: actions/checkout@v4

      - name: Build and Push
        run: |
          docker build -t gcr.io/$PROJECT_ID/myapp:${{ github.sha }} .
          docker push gcr.io/$PROJECT_ID/myapp:${{ github.sha }}
```

## Variables

### values.yaml (Defaults)

| Variable | Description | Default |
|----------|-------------|---------|
| `replicaCount` | Nombre initial de replicas | `2` |
| `image.repository` | Image Docker | `myoung34/github-runner` |
| `image.tag` | Tag de l'image | `latest` |
| `github.url` | URL du repo/org GitHub | `""` (requis) |
| `github.accessToken` | Personal Access Token | `""` (requis) |
| `github.runnerToken` | Runner registration token | `""` (alternative) |
| `github.labels` | Labels du runner | `[self-hosted, linux, x64, gke]` |
| `runner.ephemeral` | Mode éphémère | `true` |
| `runner.disableAutoUpdate` | Désactiver auto-update | `true` |
| `autoscaling.enabled` | Activer HPA | `true` |
| `autoscaling.minReplicas` | Min pods | `1` |
| `autoscaling.maxReplicas` | Max pods | `5` |

### values-dev.yaml (Dev Overrides)

| Variable | Value | Raison |
|----------|-------|--------|
| `replicaCount` | `1` | Coût réduit en dev |
| `github.labels` | `[self-hosted, linux, x64, gke, dev]` | Label `dev` ajouté |
| `autoscaling.maxReplicas` | `3` | Limite de scale en dev |
| `resources.requests.cpu` | `250m` | Ressources réduites |
| `resources.requests.memory` | `256Mi` | Ressources réduites |

### values-prd.yaml (Prod Overrides)

| Variable | Value | Raison |
|----------|-------|--------|
| `replicaCount` | `2` | Haute disponibilité |
| `github.labels` | `[self-hosted, linux, x64, gke, prd]` | Label `prd` ajouté |
| `autoscaling.maxReplicas` | `10` | Scale plus agressif |
| `podDisruptionBudget.enabled` | `true` | Protection contre disruption |

## Outputs

Après déploiement, vérifier les runners:

```bash
# Pods
kubectl get pods -n ci-cd

# Logs du runner
kubectl logs -n ci-cd -l app.kubernetes.io/name=github-actions-runners

# Status GitHub (via CLI)
gh api repos/YOUR_ORG/YOUR_REPO/actions/runners \
  --jq '.runners[] | {name, status, labels: [.labels[].name]}'
```

## Vérification des Ressources

### Script de Vérification Complet

```bash
#!/bin/bash
# verify-runners.sh - Verify GitHub Actions runners deployment

NAMESPACE="ci-cd"
RELEASE="runners"

echo "=========================================="
echo "🔍 Vérification des Runners GitHub Actions"
echo "=========================================="

# 1. Helm Release
echo -e "\n📦 1. Helm Release"
helm list -n $NAMESPACE --filter $RELEASE

# 2. Pods
echo -e "\n🐳 2. Runner Pods"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=github-actions-runners -o wide

# 3. Pod Status
echo -e "\n📊 3. Pod Status Details"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=github-actions-runners \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}'

# 4. Logs (dernières lignes)
echo -e "\n📜 4. Recent Logs"
kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=github-actions-runners --tail=20 2>/dev/null || echo "No logs available"

# 5. HPA Status
echo -e "\n⚖️ 5. HPA Status"
kubectl get hpa -n $NAMESPACE 2>/dev/null || echo "No HPA found"

# 6. Secret (existence only)
echo -e "\n🔐 6. Secret"
kubectl get secret -n $NAMESPACE | grep github || echo "No GitHub secret found"

# 7. ServiceAccount
echo -e "\n👤 7. ServiceAccount"
kubectl get sa -n $NAMESPACE | grep runners || echo "No SA found"

# 8. GitHub Runners (si gh CLI disponible)
echo -e "\n🐙 8. GitHub Runners Status"
if command -v gh &> /dev/null; then
  gh api repos/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions/runners \
    --jq '.runners[] | "  \(.name): \(.status) - labels: \([.labels[].name] | join(", "))"' 2>/dev/null || \
    echo "  Cannot fetch GitHub runners (check permissions)"
else
  echo "  gh CLI not installed"
fi

echo -e "\n=========================================="
echo "✅ Vérification terminée"
echo "=========================================="
```

### Commandes Individuelles

#### Pods et Logs
```bash
# Lister les pods
kubectl get pods -n ci-cd -l app.kubernetes.io/name=github-actions-runners

# Logs d'un pod spécifique
kubectl logs -n ci-cd runners-github-actions-runners-xxxxx

# Logs en temps réel
kubectl logs -n ci-cd -l app.kubernetes.io/name=github-actions-runners -f

# Shell dans un runner (debugging)
kubectl exec -it -n ci-cd runners-github-actions-runners-xxxxx -- /bin/bash
```

#### HPA et Scaling
```bash
# Status HPA
kubectl get hpa -n ci-cd

# Détails HPA
kubectl describe hpa -n ci-cd runners-github-actions-runners

# Scale manuel (temporaire)
kubectl scale deployment -n ci-cd runners-github-actions-runners --replicas=3
```

#### GitHub Status
```bash
# Lister les runners via API
gh api repos/YOUR_ORG/YOUR_REPO/actions/runners

# Format lisible
gh api repos/YOUR_ORG/YOUR_REPO/actions/runners \
  --jq '.runners[] | {name: .name, status: .status, busy: .busy, labels: [.labels[].name]}'

# Supprimer un runner offline
gh api -X DELETE repos/YOUR_ORG/YOUR_REPO/actions/runners/RUNNER_ID
```

### Résumé des Ressources Attendues

| Type | Count | Details |
|------|-------|---------|
| Deployment | 1 | runners-github-actions-runners |
| Pods | 1-3 (dev) | Managed by HPA |
| Secret | 1 | runners-github-actions-runners-github |
| ServiceAccount | 1 | runners-github-actions-runners |
| ClusterRole | 1 | runners-github-actions-runners |
| ClusterRoleBinding | 1 | runners-github-actions-runners |
| HPA | 1 | runners-github-actions-runners |
| PDB | 0 (dev) / 1 (prd) | Pod Disruption Budget |
| **Total** | **~7-8** | |

## Sécurité

### Fonctionnalités de Sécurité

- ✅ **PAT en Secret K8s**: Token jamais exposé dans les logs
- ✅ **RBAC limité**: Permissions minimales pour le runner
- ✅ **Mode éphémère**: Nouveau pod = nouvel environnement
- ✅ **Pas de hostPath**: Isolation du système hôte
- ✅ **Network Policy ready**: Compatible avec policies réseau

### Bonnes Pratiques

1. **Rotation du PAT**: Créer un nouveau PAT périodiquement
2. **Scope minimal**: Utiliser `repo` scope uniquement
3. **Audit des workflows**: Vérifier les PRs avant merge
4. **Labels distincts**: Séparer dev/prod avec labels différents

### Considérations

⚠️ **Attention**: Les runners ont accès au code source et peuvent exécuter des commandes arbitraires. Assurez-vous que:
- Les PRs des contributors externes sont reviewées
- Les secrets GitHub sont utilisés pour les credentials sensibles
- Les workflows utilisent des actions vérifiées

## Coût Estimé

| Resource | Specification | ~Coût/mois |
|----------|---------------|------------|
| Runner Pods (dev) | 1-3x pods, ~100m CPU, ~128Mi | Inclus dans node pool |
| Runner Pods (prd) | 2-10x pods, ~500m CPU, ~512Mi | Inclus dans node pool |
| GitHub Actions | Self-hosted = gratuit | $0 |
| **Total** | | **Inclus dans GKE** |

*Note: Les runners utilisent les resources du node pool existant (application ou runners dédié).*

## Troubleshooting

### Erreur: "Permission denied" au démarrage

Le runner ne peut pas écrire dans son répertoire de travail.

**Solution**: Vérifier que `podSecurityContext` et `securityContext` sont vides (l'image gère ses propres permissions):

```yaml
podSecurityContext: {}
securityContext: {}
```

### Erreur: "Runner not appearing in GitHub"

**Vérifications**:
1. PAT valide avec scope `repo`
2. URL GitHub correcte
3. Logs du pod: `kubectl logs -n ci-cd -l app.kubernetes.io/name=github-actions-runners`

```bash
# Vérifier la configuration
kubectl get secret -n ci-cd runners-github-actions-runners-github -o yaml
```

### Erreur: "Pods Pending - Insufficient resources"

Les nodes n'ont pas assez de CPU/mémoire.

**Solutions**:
1. Réduire les `resources.requests` dans values
2. Augmenter le node pool
3. Utiliser le bon `nodeSelector`

```bash
# Vérifier les resources disponibles
kubectl describe nodes | grep -A5 "Allocated resources"
```

### Erreur: "CrashLoopBackOff"

**Vérifications**:
1. Logs du pod pour l'erreur exacte
2. PAT expiré ou invalide
3. URL GitHub incorrecte

```bash
kubectl logs -n ci-cd runners-github-actions-runners-xxxxx --previous
```

### Runners "Offline" dans GitHub

Le pod s'est arrêté sans se désenregistrer proprement.

**Solution**: Supprimer les runners offline via API:

```bash
# Lister les runners offline
gh api repos/ORG/REPO/actions/runners --jq '.runners[] | select(.status=="offline") | .id'

# Supprimer
gh api -X DELETE repos/ORG/REPO/actions/runners/RUNNER_ID
```

## Structure des Fichiers

```
C4/infrastructure/helm/runners/
├── Chart.yaml              # Métadonnées du chart
├── values.yaml             # Valeurs par défaut
├── values-dev.yaml         # Override dev
├── values-prd.yaml         # Override production
├── README.md               # Cette documentation
└── templates/
    ├── _helpers.tpl        # Fonctions helper
    ├── deployment.yaml     # Deployment des runners
    ├── secret.yaml         # Secret GitHub
    ├── serviceaccount.yaml # ServiceAccount K8s
    ├── clusterrole.yaml    # ClusterRole RBAC
    ├── clusterrolebinding.yaml # Binding RBAC
    ├── hpa.yaml            # HorizontalPodAutoscaler
    └── pdb.yaml            # PodDisruptionBudget (prd)
```

## Références

- [myoung34/github-runner](https://github.com/myoung34/docker-github-actions-runner)
- [GitHub Self-hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [GitHub Actions Runner Registration](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners)
- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

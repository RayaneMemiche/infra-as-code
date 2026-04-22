# Identity Federation Module

Ce module configure **Workload Identity Federation (WIF)** pour permettre à GitHub Actions de s'authentifier sur GCP **sans utiliser de clés JSON de service account** (long-lived credentials).

## Pourquoi Workload Identity Federation ?

### Le Problème (Avant WIF)

```
┌─────────────────┐                    ┌─────────────────┐
│  GitHub Actions │ ── JSON Key ──────►│      GCP        │
│    (CI/CD)      │    (Secret)        │   (Resources)   │
└─────────────────┘                    └─────────────────┘
```

**Risques:**
- ❌ Clés JSON stockées dans GitHub Secrets (peuvent fuiter)
- ❌ Clés ne expirent pas automatiquement
- ❌ Difficile à révoquer et auditer
- ❌ Rotation manuelle nécessaire

### La Solution (Avec WIF)

```
┌─────────────────┐    OIDC Token     ┌─────────────────┐
│  GitHub Actions │ ─────────────────►│  GCP WIF Pool   │
│    (CI/CD)      │                   │   (Validator)   │
└─────────────────┘                   └────────┬────────┘
                                               │
                                      Validates token
                                      from GitHub OIDC
                                               │
                                               ▼
                                      ┌─────────────────┐
                                      │  Service Account │
                                      │  (terraform-dev) │
                                      └────────┬────────┘
                                               │
                                      Temporary credentials
                                      (1 hour lifetime)
                                               │
                                               ▼
                                      ┌─────────────────┐
                                      │  GCP Resources  │
                                      │  (VPC, GKE...)  │
                                      └─────────────────┘
```

**Avantages:**
- ✅ Pas de secrets stockés dans GitHub
- ✅ Credentials temporaires (1 heure max)
- ✅ Audit trail complet dans GCP
- ✅ Révocation instantanée possible
- ✅ Scope limité à un repo spécifique

## Comment ça Fonctionne

### Étape 1: GitHub génère un OIDC Token

Quand un workflow GitHub Actions démarre, GitHub génère automatiquement un token OIDC signé contenant:

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "sub": "repo:RayaneMemiche/infra-as-code:ref:refs/heads/main",
  "repository": "RayaneMemiche/infra-as-code",
  "actor": "username",
  "ref": "refs/heads/main",
  "ref_type": "branch"
}
```

### Étape 2: GCP valide le token

Le **Workload Identity Pool** vérifie:
1. Le token vient de GitHub (`issuer_uri`)
2. Le repo correspond à celui autorisé (`attribute_condition`)
3. Les attributs sont correctement mappés

### Étape 3: Échange de token

Si validé, GCP échange le token GitHub contre des **credentials temporaires** pour le Service Account `terraform-dev`.

### Étape 4: Accès aux ressources

Le workflow peut maintenant utiliser ces credentials temporaires pour créer/modifier des ressources GCP.

## Ressources Terraform Créées

### 1. Workload Identity Pool

```hcl
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
}
```

**Rôle:** Container logique pour regrouper les providers d'identité externe.

### 2. Workload Identity Provider (OIDC)

```hcl
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_provider_id = "github-provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.ref_type"   = "assertion.ref_type"
  }

  attribute_condition = "assertion.repository == 'RayaneMemiche/infra-as-code'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
```

**Rôle:** Configure comment GCP valide les tokens GitHub.

| Attribut | Source GitHub | Usage |
|----------|---------------|-------|
| `google.subject` | `assertion.sub` | Identifiant unique du workflow |
| `attribute.actor` | `assertion.actor` | Utilisateur qui a déclenché |
| `attribute.repository` | `assertion.repository` | Nom du repo (owner/repo) |
| `attribute.ref` | `assertion.ref` | Branche/tag (refs/heads/main) |
| `attribute.ref_type` | `assertion.ref_type` | Type (branch, tag) |

**Sécurité:** La condition `assertion.repository == 'RayaneMemiche/infra-as-code'` garantit que seul ce repo peut s'authentifier.

### 3. Service Account Terraform

```hcl
resource "google_service_account" "terraform" {
  account_id   = "terraform-dev"
  display_name = "Terraform Service Account (dev)"
}
```

**Rôle:** Identité GCP que GitHub Actions va "impersonate" (incarner).

### 4. IAM Roles pour le Service Account

```hcl
locals {
  terraform_roles = [
    "roles/compute.admin",                   # VPC, Subnets, Firewall
    "roles/container.admin",                 # GKE
    "roles/cloudsql.admin",                  # Cloud SQL
    "roles/iam.serviceAccountAdmin",         # Service Accounts
    "roles/iam.serviceAccountUser",          # Act as Service Account
    "roles/storage.admin",                   # GCS for state
    "roles/resourcemanager.projectIamAdmin", # IAM bindings
    "roles/artifactregistry.admin",          # Container images
    "roles/logging.admin",                   # Logging
    "roles/monitoring.admin",                # Monitoring
    "roles/servicenetworking.networksAdmin", # Private Service Connection
  ]
}
```

**Rôle:** Permissions accordées au Service Account pour gérer l'infrastructure.

| Role | Permet de gérer |
|------|-----------------|
| `compute.admin` | VPC, Subnets, Firewall, VM |
| `container.admin` | GKE Clusters, Node Pools |
| `cloudsql.admin` | Cloud SQL instances |
| `iam.serviceAccountAdmin` | Créer d'autres Service Accounts |
| `iam.serviceAccountUser` | Utiliser les Service Accounts |
| `storage.admin` | GCS buckets (Terraform state) |
| `resourcemanager.projectIamAdmin` | Gérer les IAM bindings |
| `artifactregistry.admin` | Container Registry |
| `logging.admin` | Cloud Logging |
| `monitoring.admin` | Cloud Monitoring |
| `servicenetworking.networksAdmin` | Private Service Connection |

### 5. Workload Identity Binding

```hcl
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${pool_name}/attribute.repository/RayaneMemiche/infra-as-code"
}
```

**Rôle:** Autorise les workflows du repo `RayaneMemiche/infra-as-code` à impersonate le Service Account.

## Usage dans GitHub Actions

### Workflow Example

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write  # Required for OIDC

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      # Authenticate to GCP via WIF
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/iac-rattrapage-epitech/locations/global/workloadIdentityPools/github-pool/providers/github-provider
          service_account: terraform-dev@iac-rattrapage-epitech.iam.gserviceaccount.com

      # Now you can use gcloud/terraform
      - uses: hashicorp/setup-terraform@v3

      - run: terraform init
      - run: terraform apply -auto-approve
```

**Points clés:**
1. `id-token: write` - Permet à GitHub de générer le token OIDC
2. `google-github-actions/auth@v2` - Action officielle Google pour WIF
3. Pas de secrets GCP dans le workflow!

## Diagramme de Flux Complet

```
┌──────────────────────────────────────────────────────────────────┐
│                        GitHub Actions                             │
│                                                                   │
│  1. Workflow starts                                               │
│  2. GitHub generates OIDC token (signed JWT)                     │
│     {                                                             │
│       "iss": "https://token.actions.githubusercontent.com",       │
│       "repository": "RayaneMemiche/infra-as-code",                     │
│       "ref": "refs/heads/main"                                   │
│     }                                                             │
└───────────────────────────┬──────────────────────────────────────┘
                            │
                            │ 3. Send OIDC token
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                    GCP Workload Identity Pool                     │
│                         (github-pool)                             │
│                                                                   │
│  4. Validate token:                                               │
│     ✓ Issuer = token.actions.githubusercontent.com               │
│     ✓ Repository = RayaneMemiche/infra-as-code                         │
│     ✓ Token signature valid                                       │
│                                                                   │
│  5. Map attributes:                                               │
│     google.subject = assertion.sub                                │
│     attribute.repository = RayaneMemiche/infra-as-code                 │
└───────────────────────────┬──────────────────────────────────────┘
                            │
                            │ 6. Token validated
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                 Service Account: terraform-dev                    │
│                                                                   │
│  7. Check IAM binding:                                            │
│     ✓ principalSet://...attribute.repository/RayaneMemiche/infra-as-code│
│       has roles/iam.workloadIdentityUser                         │
│                                                                   │
│  8. Generate temporary credentials (1 hour)                       │
└───────────────────────────┬──────────────────────────────────────┘
                            │
                            │ 9. Return credentials
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│                        GitHub Actions                             │
│                                                                   │
│  10. Use credentials with terraform:                              │
│      terraform init                                               │
│      terraform apply                                              │
│                                                                   │
│  11. Create/modify GCP resources                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_id` | GCP Project ID | - | Yes |
| `github_repo` | GitHub repo (owner/repo) | - | Yes |
| `wif_pool_id` | Workload Identity Pool ID | `github-pool` | No |
| `wif_provider_id` | Workload Identity Provider ID | `github-provider` | No |
| `environment` | Environment name | `dev` | No |

## Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `pool_name` | Full name of WIF Pool | `projects/xxx/locations/global/workloadIdentityPools/github-pool` |
| `pool_id` | Pool ID | `github-pool` |
| `provider_name` | Full name of WIF Provider | `projects/xxx/.../providers/github-provider` |
| `provider_id` | Provider ID | `github-provider` |
| `service_account_email` | SA email | `terraform-dev@project.iam.gserviceaccount.com` |
| `workload_identity_provider` | Full path for GitHub Actions | `projects/xxx/locations/global/...` |

## Vérification des Ressources

### Script de Vérification Complet

```bash
#!/bin/bash
# verify-identity-federation.sh - Verify all WIF resources created by Terraform

PROJECT_ID="iac-rattrapage-epitech"
POOL_ID="github-pool"
PROVIDER_ID="github-provider"
SA_EMAIL="terraform-dev@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=========================================="
echo "🔍 Vérification des ressources Identity Federation"
echo "=========================================="

# 1. Workload Identity Pool
echo -e "\n🏊 1. Workload Identity Pool"
gcloud iam workload-identity-pools describe $POOL_ID \
  --location=global \
  --project=$PROJECT_ID \
  --format="table(name,displayName,state)" 2>/dev/null && \
  echo "✅ Pool exists" || echo "❌ Pool not found"

# 2. Workload Identity Provider
echo -e "\n🔌 2. Workload Identity Provider (OIDC)"
gcloud iam workload-identity-pools providers describe $PROVIDER_ID \
  --workload-identity-pool=$POOL_ID \
  --location=global \
  --project=$PROJECT_ID \
  --format="table(name,displayName,state)" 2>/dev/null && \
  echo "✅ Provider exists" || echo "❌ Provider not found"

# 3. Service Account
echo -e "\n👤 3. Service Account"
gcloud iam service-accounts describe $SA_EMAIL \
  --project=$PROJECT_ID \
  --format="table(email,displayName)" 2>/dev/null && \
  echo "✅ Service Account exists" || echo "❌ Service Account not found"

# 4. Service Account IAM Roles
echo -e "\n🔐 4. Service Account IAM Roles (on project)"
ROLES=$(gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$SA_EMAIL" \
  --format="value(bindings.role)" 2>/dev/null)

if [ -n "$ROLES" ]; then
  echo "Roles assigned:"
  echo "$ROLES" | while read role; do echo "  ✅ $role"; done
  ROLE_COUNT=$(echo "$ROLES" | wc -l | tr -d ' ')
  echo "Total: $ROLE_COUNT roles"
else
  echo "❌ No roles found"
fi

# 5. Workload Identity Binding on Service Account
echo -e "\n🔗 5. Workload Identity Binding"
WIF_BINDING=$(gcloud iam service-accounts get-iam-policy $SA_EMAIL \
  --project=$PROJECT_ID \
  --format="yaml" 2>/dev/null | grep -A1 "workloadIdentityUser")

if [ -n "$WIF_BINDING" ]; then
  echo "✅ Workload Identity binding exists"
  gcloud iam service-accounts get-iam-policy $SA_EMAIL \
    --project=$PROJECT_ID \
    --format="table(bindings.role,bindings.members)" 2>/dev/null
else
  echo "❌ Workload Identity binding not found"
fi

# 6. Verify Provider Configuration
echo -e "\n⚙️ 6. Provider OIDC Configuration"
gcloud iam workload-identity-pools providers describe $PROVIDER_ID \
  --workload-identity-pool=$POOL_ID \
  --location=global \
  --project=$PROJECT_ID \
  --format="yaml(oidc,attributeCondition,attributeMapping)" 2>/dev/null

echo -e "\n=========================================="
echo "✅ Vérification terminée"
echo "=========================================="
```

### Commandes Individuelles

#### Workload Identity Pool
```bash
# Lister tous les pools
gcloud iam workload-identity-pools list \
  --location=global \
  --project=iac-rattrapage-epitech

# Détails du pool
gcloud iam workload-identity-pools describe github-pool \
  --location=global \
  --project=iac-rattrapage-epitech
```

#### Workload Identity Provider
```bash
# Lister les providers du pool
gcloud iam workload-identity-pools providers list \
  --workload-identity-pool=github-pool \
  --location=global \
  --project=iac-rattrapage-epitech

# Détails du provider avec configuration OIDC
gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool=github-pool \
  --location=global \
  --project=iac-rattrapage-epitech \
  --format="yaml(oidc,attributeCondition,attributeMapping)"
```

#### Service Account
```bash
# Détails du Service Account
gcloud iam service-accounts describe \
  terraform-dev@iac-rattrapage-epitech.iam.gserviceaccount.com

# Lister les clés (devrait être vide avec WIF)
gcloud iam service-accounts keys list \
  --iam-account=terraform-dev@iac-rattrapage-epitech.iam.gserviceaccount.com
```

#### IAM Roles
```bash
# Voir les rôles du Service Account sur le projet
gcloud projects get-iam-policy iac-rattrapage-epitech \
  --flatten="bindings[].members" \
  --filter="bindings.members:terraform-dev@iac-rattrapage-epitech.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

#### Workload Identity Binding
```bash
# Voir les bindings WIF sur le Service Account
gcloud iam service-accounts get-iam-policy \
  terraform-dev@iac-rattrapage-epitech.iam.gserviceaccount.com \
  --format="yaml"
```

### Résumé des Ressources Attendues

```bash
# Commande rapide pour compter les ressources
echo "=== Identity Federation Resources Count ==="
echo "WIF Pools: $(gcloud iam workload-identity-pools list --location=global --format='value(name)' --project=iac-rattrapage-epitech | grep -c github-pool)"
echo "WIF Providers: $(gcloud iam workload-identity-pools providers list --workload-identity-pool=github-pool --location=global --format='value(name)' --project=iac-rattrapage-epitech 2>/dev/null | wc -l)"
echo "Service Accounts: $(gcloud iam service-accounts list --filter='email:terraform-dev' --format='value(email)' --project=iac-rattrapage-epitech | wc -l)"
echo "SA Roles: $(gcloud projects get-iam-policy iac-rattrapage-epitech --flatten='bindings[].members' --filter='bindings.members:terraform-dev@iac-rattrapage-epitech.iam.gserviceaccount.com' --format='value(bindings.role)' | wc -l)"
```

**Ressources attendues:**
| Type | Count |
|------|-------|
| Workload Identity Pool | 1 |
| Workload Identity Provider | 1 |
| Service Account | 1 |
| IAM Role Bindings (project) | 11 |
| WIF Binding (on SA) | 1 |
| **Total** | **15** |

## Sécurité

### Bonnes Pratiques Implémentées

1. **Repo-scoped access**: Seul `RayaneMemiche/infra-as-code` peut s'authentifier
2. **Temporary credentials**: Les tokens expirent après 1 heure
3. **No secrets in GitHub**: Pas de JSON key dans les secrets
4. **Audit trail**: Toutes les authentifications sont loggées dans GCP
5. **Least privilege possible**: Les rôles sont limités à ce qui est nécessaire

### Restrictions Optionnelles

Pour plus de sécurité, vous pouvez restreindre à une branche spécifique:

```hcl
# Seulement la branche main peut s'authentifier
resource "google_service_account_iam_member" "workload_identity_binding_main" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${pool_name}/attribute.ref/refs/heads/main"
}
```

## Troubleshooting

### Erreur: "Unable to exchange token"

1. Vérifier que `id-token: write` est dans les permissions du workflow
2. Vérifier que le repo correspond exactement à `attribute_condition`
3. Vérifier que le provider path est correct dans le workflow

### Erreur: "Permission denied"

1. Vérifier que le Service Account a les rôles nécessaires
2. Vérifier que le binding WIF existe sur le Service Account

### Test de connectivité

```yaml
- name: Test GCP Auth
  run: |
    gcloud auth list
    gcloud projects describe ${{ env.PROJECT_ID }}
```

## Références

- [GCP Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub OIDC with GCP](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform)
- [google-github-actions/auth](https://github.com/google-github-actions/auth)

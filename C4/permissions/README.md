# C4 Permissions Stack

Stack Terraform séparée pour la gestion des permissions IAM GCP (équipe).

## Architecture

```
C4/
├── infrastructure/     ← Stack Infra (APIs, WIF, VPC, GKE...)
│
└── permissions/        ← Cette stack (PERMISSIONS)
    ├── terraform.tf    → Provider + Backend GCS
    ├── main.tf         → IAM équipe (prof, étudiants, billing)
    ├── variables.tf    → Variables d'entrée
    ├── outputs.tf      → Outputs
    └── environments/
        └── dev/terraform.tfvars
```

## Ressources Gérées

- **Professor Access** : Accès viewer pour les professeurs
- **Student Access** : Accès editor pour les étudiants
- **Service Account Access** : Accès pour les SA externes
- **Billing Viewer** : Accès lecture aux coûts

## Pourquoi une Stack Séparée ?

1. **Séparation des responsabilités** : Infra et permissions ont des cycles de vie différents
2. **Sécurité** : Les permissions peuvent être gérées par des personnes différentes
3. **State isolation** : Un changement de permission ne risque pas de casser l'infra
4. **Blast radius** : Limiter l'impact des erreurs

## Commandes

### 1. Initialiser

```bash
cd /Users/josephyu/conductor/workspaces/infra-as-code/babylon/C4/permissions
terraform init
```

### 2. Valider la configuration

```bash
terraform validate
```

### 3. Voir les changements planifiés

```bash
terraform plan -var-file=environments/dev/terraform.tfvars
```

### 4. Appliquer les changements

```bash
terraform apply -var-file=environments/dev/terraform.tfvars
```

### 5. Appliquer sans confirmation (CI/CD)

```bash
terraform apply -var-file=environments/dev/terraform.tfvars -auto-approve
```

### 6. Voir l'état actuel

```bash
terraform state list
```

### 7. Voir les outputs

```bash
terraform output
```

### 8. Détruire les permissions

```bash
terraform destroy -var-file=environments/dev/terraform.tfvars
```

## Gestion des Accès

### Ajouter un Professeur

1. Modifier `environments/dev/terraform.tfvars`:

```hcl
professors = {
  # Existants...

  nouveau_prof = {
    email = "nouveau.prof@example.com"
    role  = "roles/viewer"
  }
}
```

2. Appliquer:

```bash
terraform apply -var-file=environments/dev/terraform.tfvars
```

### Ajouter un Étudiant

1. Modifier `environments/dev/terraform.tfvars`:

```hcl
students = {
  # Existants...

  nouveau_etudiant = {
    email = "nouveau@epitech.eu"
    role  = "roles/editor"
  }
}
```

2. Appliquer:

```bash
terraform apply -var-file=environments/dev/terraform.tfvars
```

### Supprimer un Utilisateur

1. Retirer l'entrée du fichier `terraform.tfvars`
2. Appliquer:

```bash
terraform plan -var-file=environments/dev/terraform.tfvars
# Vérifier que le plan montre "destroy" pour l'utilisateur
terraform apply -var-file=environments/dev/terraform.tfvars
```

### Modifier un Rôle

1. Changer le `role` dans `terraform.tfvars`:

```hcl
students = {
  etudiant1 = {
    email = "etudiant1@epitech.eu"
    role  = "roles/viewer"  # Changé de editor à viewer
  }
}
```

2. Appliquer:

```bash
terraform apply -var-file=environments/dev/terraform.tfvars
```

### Ajouter un Billing Viewer

1. Modifier `terraform.tfvars`:

```hcl
billing_viewers = [
  "jeremie@jjaouen.com",
  "nouveau@example.com"  # Ajouter ici
]
```

2. Appliquer:

```bash
terraform apply -var-file=environments/dev/terraform.tfvars
```

## Rôles Disponibles

| Rôle | Description | Cas d'usage |
|------|-------------|-------------|
| `roles/viewer` | Lecture seule | Professeurs, reviewers |
| `roles/editor` | Lecture + écriture | Étudiants, développeurs |
| `roles/owner` | Tout accès | **Éviter** (trop permissif) |
| `roles/billing.viewer` | Voir les coûts | Professeurs |

### Rôles Spécifiques (optionnel)

```hcl
# Accès limité à certains services
role = "roles/compute.viewer"        # VMs seulement
role = "roles/container.viewer"      # GKE seulement
role = "roles/storage.objectViewer"  # GCS seulement
```

## Vérification GCP

### Voir tous les accès du projet

```bash
gcloud projects get-iam-policy fourth-outpost-479614-t4 \
  --flatten="bindings[].members" \
  --format="table(bindings.role, bindings.members)"
```

### Vérifier un utilisateur spécifique

```bash
gcloud projects get-iam-policy fourth-outpost-479614-t4 \
  --flatten="bindings[].members" \
  --filter="bindings.members:EMAIL@example.com" \
  --format="table(bindings.role)"
```

### Voir les billing viewers

```bash
gcloud billing accounts get-iam-policy 01387B-7CABD9-464F50 \
  --format="table(bindings.role, bindings.members)"
```

## Suppression d'Urgence (sans Terraform)

Si besoin de supprimer un accès immédiatement:

```bash
# Supprimer un accès projet
gcloud projects remove-iam-policy-binding fourth-outpost-479614-t4 \
  --member="user:EMAIL@example.com" \
  --role="roles/editor"

# Supprimer un accès billing
gcloud billing accounts remove-iam-policy-binding 01387B-7CABD9-464F50 \
  --member="user:EMAIL@example.com" \
  --role="roles/billing.viewer"

# Puis synchroniser Terraform
terraform refresh -var-file=environments/dev/terraform.tfvars
```

## Configuration Actuelle

### Professeurs
| Nom | Email | Rôle |
|-----|-------|------|
| jjaouen | jeremie@jjaouen.com | roles/viewer |

### Étudiants
| Nom | Email | Rôle |
|-----|-------|------|
| lenny | lenny.vongphouthone@epitech.eu | roles/editor |
| yorenn | yorennzzelina@hotmail.fr | roles/editor |

### Billing Viewers
- jeremie@jjaouen.com

## Troubleshooting

### "User not found"

L'email n'est pas un compte Google valide. L'utilisateur doit créer un compte Google.

### "Permission denied"

1. Vérifier que `terraform apply` a réussi
2. Vérifier l'email exact (pas de typo)
3. L'utilisateur doit se connecter avec le bon email

### Accès qui ne part pas

```bash
# Forcer via gcloud
gcloud projects remove-iam-policy-binding fourth-outpost-479614-t4 \
  --member="user:EMAIL" \
  --role="ROLE"

# Synchroniser Terraform
terraform refresh -var-file=environments/dev/terraform.tfvars
```

## Prérequis pour les Utilisateurs

### Email Google requis

L'email doit être un compte Google:
- Gmail (`@gmail.com`)
- Google Workspace (`@entreprise.com` géré par Google)
- Compte Google créé avec un autre email

### Créer un compte Google avec email existant

1. Aller sur `https://accounts.google.com/signup`
2. Cliquer "Utiliser mon adresse e-mail actuelle"
3. Entrer l'email existant
4. Valider

### Accès après configuration

Une fois ajouté via Terraform:
1. Aller sur `https://console.cloud.google.com`
2. Se connecter avec l'email configuré
3. Sélectionner le projet `fourth-outpost-479614-t4`

## Voir aussi

- [Infrastructure Stack](../infrastructure/README.md) - Gestion de l'infrastructure
- [C4 README Principal](../README.md) - Vue d'ensemble du projet

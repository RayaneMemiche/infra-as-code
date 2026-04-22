# Running Entrypoints

## Provision Infrastructure (Terraform)
```bash
cd C4/infrastructure
terraform init
terraform apply -var-file=environments/dev/terraform.tfvars
```

## Apply Permissions (Terraform)
```bash
cd C4/permissions
terraform init
terraform apply -var-file=environments/dev/terraform.tfvars
```

## Deploy Application (Helm)
```bash
# 1) Ensure GKE credentials
gcloud container clusters get-credentials c4-cluster-dev --region europe-west1 --project iac-rattrapage-epitech

# 2) Create/update secrets interactively
./C4/scripts/setup-secrets.sh

# 3) Deploy to cluster (dev)
./C4/scripts/deploy-local.sh dev dev

# 4) Access locally
kubectl port-forward svc/task-manager-api 8080:80 -n task-manager
```

## Run App Locally (Node.js)
```bash
cd task-manager-api
npm install
npm run dev   # starts on PORT from env or 3000
```

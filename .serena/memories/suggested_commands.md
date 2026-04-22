# Suggested Commands (macOS/Darwin)

## Prerequisites (install)
```bash
brew install terraform
brew install --cask google-cloud-sdk
brew install kubectl
brew install helm
```

## Authenticate to GCP
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project fourth-outpost-479614-t4
```

## Terraform — Infrastructure Stack
```bash
cd C4/infrastructure
terraform init
terraform validate
terraform fmt -recursive
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
terraform output
terraform state list
# Destroy when needed
terraform destroy -var-file=environments/dev/terraform.tfvars
```

## Terraform — Permissions Stack
```bash
cd C4/permissions
terraform init
terraform validate
terraform fmt -recursive
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
terraform output
terraform state list
terraform destroy -var-file=environments/dev/terraform.tfvars
```

## Verify Resources (gcloud)
```bash
gcloud compute networks list --project=fourth-outpost-479614-t4
gcloud compute networks subnets list --project=fourth-outpost-479614-t4
gcloud compute firewall-rules list --project=fourth-outpost-479614-t4
gcloud compute routers nats list --router=c4-vpc-dev-router --region=europe-west1
# WIF
gcloud iam workload-identity-pools list --location=global
```

## Helm — Deploy Task Manager API (local)
```bash
# prepare secrets first (interactive)
./C4/scripts/setup-secrets.sh

# deploy app on GKE
./C4/scripts/deploy-local.sh dev dev

# access locally
kubectl port-forward svc/task-manager-api 8080:80 -n task-manager
```

## Helm — Manual (alternative)
```bash
NAMESPACE=task-manager
CHART=C4/infrastructure/helm/task-manager-api
helm upgrade --install task-manager-api "$CHART" \
  --namespace "$NAMESPACE" --create-namespace \
  --values "$CHART/values-dev.yaml" --wait --timeout 5m
```

## App (Node.js) — Local
```bash
cd task-manager-api
npm install
npm run dev   # or: npm start
```

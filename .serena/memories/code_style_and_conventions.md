# Code Style & Conventions

## Terraform
- Run `terraform fmt -recursive` before commits/PRs
- Keep modules cohesive: identity-federation, networking, gke, database, etc.
- Use variables via `environments/dev/terraform.tfvars`; avoid hardcoding
- Naming pattern (dev): `c4-<component>-dev` (e.g., `c4-vpc-dev`, `c4-cluster-dev`)
- Labels (example from tfvars): project, environment, managed-by, course
- Separate stacks for infra and permissions (distinct backends/states)

## Git Workflow Hints
- Feature branches: `feature/<topic>`
- Example commit message: `feat(infra): add GKE cluster module`
- Validate/plan before PR merge
- Tagging after merges for deploy milestones (optional)

## Helm Charts
- Keep `values-*.yaml` per environment; don’t commit secrets
- Use `helm lint` locally when editing templates
- Prefer `Deployment` resources with HPA and PDB configured (already present)

## Kubernetes
- Namespaces: use dedicated namespaces (e.g., `task-manager`)
- Use Workload Identity for GCP access (no key files in repo)

## Node.js App
- Minimal scripts: `npm run dev`, `npm start`
- Use `dotenv` locally (no .env committed) and Kubernetes secrets in cluster

## Security & Secrets
- No credentials committed; auth via `gcloud` locally and WIF in CI
- Create K8s secrets via `C4/scripts/setup-secrets.sh`
- Cloud SQL creds synced via External Secrets (values reference secret names)

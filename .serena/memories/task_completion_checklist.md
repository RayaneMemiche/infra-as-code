# Task Completion Checklist

Before opening a PR or marking a task done:

## Terraform
- `terraform fmt -recursive` (no diffs)
- `terraform validate` passes
- `terraform plan -var-file=environments/dev/terraform.tfvars` reviewed
- No hardcoded sensitive values; secrets piped via variables or Secret Manager
- Module outputs documented when relevant

## Helm/Kubernetes (if changed)
- `helm lint` on modified charts
- Templates render with expected values overrides
- Secrets present or created via `setup-secrets.sh`

## GCP/WIF
- Confirm required APIs enabled and IAM bindings in place via `gcloud` checks if relevant

## Docs & PR
- Updated README or docs if behavior changes
- Clear commit message and PR description (what/why/how)
- Linked issue/ticket (if applicable)

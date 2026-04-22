# C4 Permissions Stack - Architecture Diagram

## Overview

La **Permissions Stack** est une stack Terraform isolée qui gère exclusivement les permissions IAM GCP pour l'équipe du projet C4.

---

## Architecture Diagram

```mermaid
flowchart TB
    subgraph CONFIG["terraform.tfvars (Dev)"]
        TFVARS["project_id = fourth-outpost-479614-t4<br/>region = europe-west1<br/>environment = dev"]
    end

    subgraph VARS["variables.tf"]
        V1["project_id<br/>region<br/>environment"]
        V2["professors<br/>map(object)"]
        V3["students<br/>map(object)"]
        V4["service_accounts<br/>map(object)"]
        V5["billing_account_id<br/>billing_viewers"]
    end

    subgraph MAIN["main.tf (Resources)"]
        subgraph PROJECT_IAM["GCP Project IAM Bindings"]
            R1["google_project_iam_member<br/><b>professor_access</b><br/>for_each = var.professors"]
            R2["google_project_iam_member<br/><b>student_access</b><br/>for_each = var.students"]
            R3["google_project_iam_member<br/><b>service_account_access</b><br/>for_each = var.service_accounts"]
        end
        subgraph BILLING_IAM["Billing Account IAM"]
            R4["google_billing_account_iam_member<br/><b>billing_viewer</b><br/>for_each = var.billing_viewers"]
        end
    end

    subgraph GCP["GCP IAM API"]
        subgraph PROJ["Project: fourth-outpost-479614-t4"]
            P1["user:jeremie@jjaouen.com → roles/viewer"]
            P2["user:lenny...@epitech.eu → roles/editor"]
            P3["user:yorennzzelina@... → roles/editor"]
        end
        subgraph BILL["Billing: 01387B-7CABD9-464F50"]
            B1["user:jeremie@jjaouen.com → billing.viewer"]
        end
    end

    subgraph OUTPUTS["outputs.tf"]
        O1["professor_bindings"]
        O2["student_bindings"]
        O3["service_account_bindings"]
        O4["billing_viewers"]
    end

    CONFIG --> VARS
    V1 --> R1 & R2 & R3
    V2 --> R1
    V3 --> R2
    V4 --> R3
    V5 --> R4

    R1 --> P1
    R2 --> P2 & P3
    R4 --> B1

    P1 & P2 & P3 --> O1 & O2 & O3
    B1 --> O4

    style CONFIG fill:#ffec99,stroke:#e67700
    style VARS fill:#b2f2bb,stroke:#2f9e44
    style MAIN fill:#ffc9c9,stroke:#c92a2a
    style GCP fill:#a5d8ff,stroke:#1971c2
    style OUTPUTS fill:#e9ecef,stroke:#495057
```

---

## Data Flow Diagram

```mermaid
flowchart LR
    A["terraform.tfvars<br/>(Configuration)"] --> B["variables.tf<br/>(Input Schema)"]
    B --> C["main.tf<br/>(Resources)"]
    C --> D["GCP IAM API"]
    D --> E["outputs.tf<br/>(Exports)"]

    style A fill:#ffec99,stroke:#e67700
    style B fill:#b2f2bb,stroke:#2f9e44
    style C fill:#ffc9c9,stroke:#c92a2a
    style D fill:#a5d8ff,stroke:#1971c2
    style E fill:#e9ecef,stroke:#495057
```

---

## State Isolation Diagram

```mermaid
flowchart TB
    subgraph BUCKET["GCS Bucket: tfstate-fourth-outpost-479614-t4"]
        subgraph INFRA["infrastructure/dev/terraform.tfstate"]
            I1["VPC"]
            I2["Subnets"]
            I3["GKE Cluster"]
            I4["Cloud SQL"]
            I5["Workload Identity"]
            I6["NAT Gateway"]
        end
        subgraph PERM["permissions/dev/terraform.tfstate"]
            P1["Professor IAM bindings"]
            P2["Student IAM bindings"]
            P3["Service Account bindings"]
            P4["Billing viewer bindings"]
        end
    end

    INFRA --> HIGH["Blast Radius: HIGH<br/>(Infrastructure)"]
    PERM --> LOW["Blast Radius: LOW<br/>(Permissions only)"]

    style INFRA fill:#ffc9c9,stroke:#c92a2a
    style PERM fill:#b2f2bb,stroke:#2f9e44
    style HIGH fill:#ff8787,stroke:#c92a2a
    style LOW fill:#8ce99a,stroke:#2f9e44
```

### Benefits of Separation

| # | Benefit |
|---|---------|
| 1 | Independent lifecycles |
| 2 | Different change frequencies |
| 3 | Limited blast radius |
| 4 | Separate access control |
| 5 | Faster terraform operations |

---

## Role Hierarchy Diagram

```mermaid
flowchart TB
    subgraph PROJECT["GCP Project Roles"]
        OWNER["roles/owner<br/>(NOT USED - risk)"]
        EDITOR["roles/editor<br/>(Read + Write)"]
        VIEWER["roles/viewer<br/>(Read Only)"]

        OWNER --> EDITOR --> VIEWER
    end

    subgraph USERS["Current Assignments"]
        STUDENTS["STUDENTS<br/>lenny, yorenn"]
        PROFS["PROFESSORS<br/>jjaouen"]
    end

    EDITOR -.- STUDENTS
    VIEWER -.- PROFS

    subgraph BILLING["Billing Account"]
        BVIEW["roles/billing.viewer<br/>(View costs only)"]
        BVIEW -.- PROFS
    end

    style OWNER fill:#ff8787,stroke:#c92a2a
    style EDITOR fill:#b2f2bb,stroke:#2f9e44
    style VIEWER fill:#a5d8ff,stroke:#1971c2
    style BVIEW fill:#ffec99,stroke:#e67700
    style STUDENTS fill:#b2f2bb,stroke:#2f9e44
    style PROFS fill:#a5d8ff,stroke:#1971c2
```

---

## Terraform Resource Map

```mermaid
flowchart LR
    subgraph TF["terraform.tf"]
        PROVIDER["provider google<br/>project, region"]
        BACKEND["backend gcs<br/>bucket, prefix"]
    end

    subgraph VARIABLES["variables.tf"]
        VP["var.project_id"]
        VPROF["var.professors"]
        VSTUD["var.students"]
        VSA["var.service_accounts"]
        VBILL["var.billing_account_id<br/>var.billing_viewers"]
    end

    subgraph RESOURCES["main.tf"]
        RPROF["professor_access"]
        RSTUD["student_access"]
        RSA["service_account_access"]
        RBILL["billing_viewer"]
    end

    subgraph OUT["outputs.tf"]
        OPROF["professor_bindings"]
        OSTUD["student_bindings"]
        OSA["service_account_bindings"]
        OBILL["billing_viewers"]
    end

    VP --> RPROF & RSTUD & RSA
    VPROF --> RPROF
    VSTUD --> RSTUD
    VSA --> RSA
    VBILL --> RBILL

    RPROF --> OPROF
    RSTUD --> OSTUD
    RSA --> OSA
    RBILL --> OBILL

    style TF fill:#e9ecef,stroke:#495057
    style VARIABLES fill:#b2f2bb,stroke:#2f9e44
    style RESOURCES fill:#ffc9c9,stroke:#c92a2a
    style OUT fill:#a5d8ff,stroke:#1971c2
```

---

## Current Configuration Summary

| Category | Key | Email | Role | Access Level |
|----------|-----|-------|------|--------------|
| **Professors** | jjaouen | jeremie@jjaouen.com | roles/viewer | Read-only project |
| **Students** | lenny | lenny.vongphouthone@epitech.eu | roles/editor | Read + Write |
| **Students** | yorenn | yorennzzelina@hotmail.fr | roles/editor | Read + Write |
| **Service Accounts** | (none) | - | - | - |
| **Billing Viewers** | - | jeremie@jjaouen.com | billing.viewer | View costs only |

**Project**: `fourth-outpost-479614-t4`
**Region**: `europe-west1`
**Environment**: `dev`

---

## Access Matrix

| User | Project View | Project Edit | Billing View | Create Resources | Delete Resources |
|------|:------------:|:------------:|:------------:|:----------------:|:----------------:|
| jjaouen (prof) | ✅ | ❌ | ✅ | ❌ | ❌ |
| lenny (student) | ✅ | ✅ | ❌ | ✅ | ✅ |
| yorenn (student) | ✅ | ✅ | ❌ | ✅ | ✅ |

---

## File Structure

```mermaid
flowchart TB
    subgraph C4["C4/"]
        subgraph INFRA["infrastructure/"]
            TF1["terraform.tf"]
            M1["main.tf"]
            V1["variables.tf"]
            O1["outputs.tf"]
            E1["environments/dev/terraform.tfvars"]
        end
        subgraph PERM["permissions/ (Cette Stack)"]
            TF2["terraform.tf - Provider + Backend GCS"]
            M2["main.tf - IAM resources (4 types)"]
            V2["variables.tf - Input variables (8 vars)"]
            O2["outputs.tf - Outputs (4 outputs)"]
            E2["environments/dev/terraform.tfvars"]
        end
    end

    style INFRA fill:#e9ecef,stroke:#495057
    style PERM fill:#b2f2bb,stroke:#2f9e44
```

---

## Workflow Diagram

```mermaid
flowchart TD
    START([START]) --> EDIT
    EDIT["1. Edit terraform.tfvars<br/>Add/Remove users<br/>Change roles"] --> PLAN
    PLAN["2. terraform plan<br/>-var-file=...tfvars"] --> REVIEW
    REVIEW{"Review changes:<br/>+ add (new users)<br/>~ change (updates)<br/>- destroy (removals)"}
    REVIEW -->|Approve| APPLY
    REVIEW -->|Reject| EDIT
    APPLY["3. terraform apply<br/>-var-file=...tfvars"] --> VERIFY
    VERIFY["4. Verify via gcloud:<br/>gcloud projects get-iam-policy PROJECT"] --> END1([END])

    style START fill:#2f9e44,stroke:#1e1e1e,color:#fff
    style END1 fill:#c92a2a,stroke:#1e1e1e,color:#fff
    style REVIEW fill:#ffec99,stroke:#e67700
```

---

## Security Considerations

```mermaid
mindmap
  root((Security<br/>Best Practices))
    Least Privilege
      Professors: roles/viewer
        Cannot modify resources
        Observe for evaluation
      Students: roles/editor
        Can create/modify
        Cannot delete project
      No roles/owner
        Too permissive
        Reserved for owner
    State Isolation
      Separate state files
      Independent blast radius
      Different access patterns
    Declarative Management
      All permissions in code
      Version controlled
      Auditable changes
      Reproducible state
    Billing Separation
      Only professors view costs
      Students no billing access
      Cost awareness
```

---

## Quick Reference Commands

```bash
# Initialize
cd C4/permissions
terraform init

# Plan changes
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply changes
terraform apply -var-file=environments/dev/terraform.tfvars

# View current state
terraform state list

# View outputs
terraform output

# Verify in GCP
gcloud projects get-iam-policy fourth-outpost-479614-t4 \
  --flatten="bindings[].members" \
  --format="table(bindings.role, bindings.members)"
```

---

## Related Documentation

- [C4 Permissions README](../permissions/README.md) - Usage guide
- [C4 Infrastructure README](../infrastructure/README.md) - Infrastructure stack
- [C4 Project Structure](../../C4_PROJECT_STRUCTURE.md) - Overall structure
- [C4 Implementation Plan](../../C4_IMPLEMENTATION_PLAN.md) - Full implementation guide

# Infrastructure as Code (IaC) Course - Epitech

> **Main deliverable: [C4 Final Project](C4/README.md)** - Cloud-Native Infrastructure with Terraform, Kubernetes, Helm & GitHub Actions on GCP.

## 📚 Course Structure

```
.
├── C4/                           # Course 4: Final Project - Cloud-Native IaC (MAIN DELIVERABLE)
│   ├── infrastructure/           # Terraform stack: GKE, VPC, DB, Monitoring
│   │   ├── modules/              # identity-federation, networking, gke, database, monitoring
│   │   └── helm/                 # runners, task-manager-api, monitoring
│   ├── permissions/              # Terraform stack: IAM (prof, students)
│   ├── load-testing/             # Locust load-testing scenarios
│   ├── docs/                     # Architecture diagrams, defense plan
│   └── README.md                 # C4 project documentation
│
├── task-manager-api/             # Task Manager REST API (Node.js/Express)
│   ├── src/                      # Application source code
│   ├── Dockerfile                # Container image
│   └── package.json
│
└── README.md                      # This file
```

---

## 🚀 Quick Start

### Navigate to C2 folder
```bash
cd C2
```

### Check infrastructure status
```bash
bash health-check.sh
```

### View deployed resources
```bash
terraform output
```

### Manage infrastructure
```bash
# Preview changes
terraform plan -var-file=dev.tfvars

# Deploy
terraform apply -var-file=dev.tfvars

# Cleanup
terraform destroy -var-file=dev.tfvars
```

---

## 🏗️ C4 - Final Project (Main Deliverable)

The **C4 project** is the main deliverable for this course. It implements a full cloud-native infrastructure on GCP using Terraform, Kubernetes, and Helm.

### What is included

- **2 Terraform stacks** (infrastructure + permissions) with isolated state
- **GKE Cluster** with 3 node pools (application, runners, monitoring)
- **Cloud SQL PostgreSQL** with private networking
- **Workload Identity Federation** for keyless CI/CD from GitHub Actions
- **3 Helm Charts**: runners, task-manager-api, monitoring (Prometheus + Grafana)
- **Task Manager REST API** (Node.js/Express) with authentication, rate limiting, and full CRUD
- **Monitoring stack** with Prometheus, Grafana dashboards, and alerting rules
- **Load testing** with Locust for validating scalability under load
- **CI/CD pipelines** via GitHub Actions (validate, plan, apply, build, destroy)

### Quick Start (C4)

```bash
cd C4/infrastructure
terraform init
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

See [C4/README.md](C4/README.md) for full documentation and [C4/docs/DEFENSE_PLAN.md](C4/docs/DEFENSE_PLAN.md) for the defense preparation guide.

---

## 📖 Documentation

### C2 Folder Contents

| File | Purpose |
|------|---------|
| **main.tf** | VPC network and subnet definitions |
| **variables.tf** | Input parameters for the infrastructure |
| **outputs.tf** | Output values after deployment |
| **terraform.tf** | Backend configuration (GCS) |
| **dev.tfvars** | Environment-specific values |
| **backends/dev.config** | GCS bucket configuration |
| **health-check.sh** | Script to verify infrastructure status |
| **README.md** | Quick start and reference guide |
| **TRACKING_GUIDE.md** | How to monitor your infrastructure |
| **WHAT_WAS_CREATED.md** | Detailed breakdown of all resources |
| **C2-IaC-Fundamentals.md** | Original course assignment document |
| **.gitignore** | Git ignore rules for Terraform |

---

## 🌐 Deployed Infrastructure

### GCP Project
- **Project ID**: `fourth-outpost-479614-t4`
- **Region**: `europe-west1`

### Resources
- **VPC Network**: `gcp-test` ✅ ACTIVE
- **Subnet**: `gcp-test-subnet` (10.0.1.0/24) ✅ READY
- **State Storage**: GCS Bucket `tfstate-fourth-outpost-479614-t4`

---

## 📋 Project Details

### VPC Network
```
Name:      gcp-test
Region:    Global
Status:    Active
Subnets:   1
```

### Subnet
```
Name:         gcp-test-subnet
CIDR:         10.0.1.0/24
Region:       europe-west1
Gateway:      10.0.1.1
Available:    254 IPs (10.0.1.2 - 10.0.1.254)
Status:       Ready
```

---

## 🔗 GCP Console Links

- [VPC Networks](https://console.cloud.google.com/vpc/networks?project=fourth-outpost-479614-t4)
- [VPC Network Details](https://console.cloud.google.com/vpc/networks/details/gcp-test?project=fourth-outpost-479614-t4)
- [Subnet Details](https://console.cloud.google.com/vpc/networks/subnets/details/europe-west1/gcp-test-subnet?project=fourth-outpost-479614-t4)

---

## 💻 Essential Commands

```bash
# Initialize Terraform (first time only)
terraform init -backend-config="./backends/dev.config"

# Preview changes
terraform plan -var-file=dev.tfvars

# Deploy infrastructure
terraform apply -var-file=dev.tfvars

# View outputs
terraform output

# Check resource details
terraform state show google_compute_network.main
terraform state show google_compute_subnetwork.main

# Monitor infrastructure
bash health-check.sh

# Cleanup resources
terraform destroy -var-file=dev.tfvars
```

---

## 📂 File Organization

### Terraform Code
- `main.tf` - Provider + Resources
- `variables.tf` - Input definitions
- `outputs.tf` - Output definitions
- `terraform.tf` - Backend setup

### Configuration
- `dev.tfvars` - Development values
- `backends/dev.config` - Backend values

### Documentation
- `README.md` - Quick reference
- `TRACKING_GUIDE.md` - Monitoring
- `WHAT_WAS_CREATED.md` - Details
- `C2-IaC-Fundamentals.md` - Assignment

### Tools
- `health-check.sh` - Verification script
- `.gitignore` - Git configuration

---

## 🔐 Security

- ✅ No credentials hardcoded
- ✅ State file stored remotely (GCS)
- ✅ Variables for all inputs
- ✅ .gitignore configured
- ✅ Sensitive values protected

---

## 📚 Learning Resources

### Course Documents
- See `C2-IaC-Fundamentals.md` for assignment details

### Quick References
- See `README.md` in C2 folder for quick start
- See `TRACKING_GUIDE.md` for monitoring
- See `WHAT_WAS_CREATED.md` for details

### Official Documentation
- [Terraform Docs](https://www.terraform.io/docs)
- [Google Cloud Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP VPC Documentation](https://cloud.google.com/vpc/docs)

---

## ✅ Course Progress

### C2 - IaC Fundamentals
- [x] Prerequisites setup
- [x] Terraform basics
- [x] VPC deployment
- [x] Subnet deployment
- [x] Remote state management
- [x] Local testing
- [x] Documentation

### C4 - Final Project (Main Deliverable)
- [x] GCP APIs + Workload Identity Federation
- [x] Networking (VPC, Subnet, NAT, Firewall)
- [x] GKE Cluster + 3 node pools
- [x] Cloud SQL PostgreSQL (database module)
- [x] Helm Charts (runners, task-manager-api, monitoring)
- [x] Task Manager REST API (Node.js/Express)
- [x] Monitoring (Prometheus + Grafana)
- [x] CI/CD Pipelines (GitHub Actions)
- [x] Load testing (Locust)
- [x] Team permissions (IAM stack)
- [x] Documentation + Defense plan

---

## 📝 Next Steps

1. **Review C4 infrastructure**
   ```bash
   cd C4/infrastructure
   terraform plan -var-file=environments/dev/terraform.tfvars
   ```

2. **Deploy and test the application**
   ```bash
   kubectl port-forward svc/task-manager-api -n task-manager 8080:80
   curl http://localhost:8080/health
   ```

3. **Run load tests**
   ```bash
   cd C4/load-testing
   locust -f locustfile.py --host=http://localhost:8080
   ```

4. **Check monitoring**
   ```bash
   kubectl port-forward svc/c4-monitoring-grafana -n monitoring 3000:80
   ```

5. **Prepare for defense**
   - See [C4/docs/DEFENSE_PLAN.md](C4/docs/DEFENSE_PLAN.md)
   - Verify all resources are running
   - Practice the demo flow

---

## 🆘 Troubleshooting

### Issue: Can't initialize Terraform
**Solution**: Make sure you're in the C2 folder
```bash
cd C2
terraform init -backend-config="./backends/dev.config"
```

### Issue: terraform apply fails
**Solution**: Verify GCP credentials
```bash
gcloud auth list
gcloud config set project fourth-outpost-479614-t4
```

### Issue: Can't see state file in GCS
**Solution**: List bucket contents
```bash
gsutil ls gs://tfstate-fourth-outpost-479614-t4/terraform/state/
```

For more troubleshooting, see C2/README.md

---

## 📞 Support

- Check course materials: `C2/C2-IaC-Fundamentals.md`
- Check quick start: `C2/README.md`
- Check monitoring guide: `C2/TRACKING_GUIDE.md`
- Check detailed info: `C2/WHAT_WAS_CREATED.md`

---

**Status**: ✅ C4 Final Project Complete - Infrastructure Deployed and Ready
**Last Updated**: 2026-04-22

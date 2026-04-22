# Networking Module

Ce module crée l'infrastructure réseau pour le projet C4: **VPC**, **Subnet**, **Cloud NAT**, et **Firewall rules**.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           VPC: c4-vpc-dev                                    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                    Subnet: c4-vpc-dev-subnet                           │ │
│  │                    CIDR: 10.0.0.0/20                                   │ │
│  │                                                                         │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │ │
│  │  │              Secondary Ranges (for GKE)                          │  │ │
│  │  │                                                                  │  │ │
│  │  │  ┌────────────────────┐    ┌────────────────────┐              │  │ │
│  │  │  │  Pods Range        │    │  Services Range    │              │  │ │
│  │  │  │  10.1.0.0/16       │    │  10.2.0.0/20       │              │  │ │
│  │  │  │  ~65K IPs          │    │  ~4K IPs           │              │  │ │
│  │  │  └────────────────────┘    └────────────────────┘              │  │ │
│  │  └─────────────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────┐        ┌──────────────────────────────────────────┐│
│  │   Cloud Router     │        │           Cloud NAT                      ││
│  │   ASN: 64514       │◄──────►│   • Auto IP allocation                   ││
│  │                    │        │   • All subnets                          ││
│  └────────────────────┘        │   • Egress for private nodes             ││
│                                └──────────────────────────────────────────┘│
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         Firewall Rules                                │  │
│  │                                                                       │  │
│  │  ✅ allow-internal      (VPC internal traffic)         Priority 1000 │  │
│  │  ✅ allow-http-https    (80/443 for LB)                Priority 1000 │  │
│  │  ✅ allow-health-checks (GCP LB probes)                Priority 1000 │  │
│  │  ✅ allow-ssh           (IAP only - 35.235.240.0/20)   Priority 1000 │  │
│  │  ❌ deny-all-ingress    (default deny)                 Priority 65534│  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                   Private Service Connection                          │  │
│  │                   (for Cloud SQL peering)                             │  │
│  │                                                                       │  │
│  │   Reserved IP Range ──────► servicenetworking.googleapis.com         │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Ressources Terraform Créées

| Resource | Name | Description |
|----------|------|-------------|
| `google_compute_network` | c4-vpc-dev | VPC network |
| `google_compute_subnetwork` | c4-vpc-dev-subnet | Main subnet with secondary ranges |
| `google_compute_router` | c4-vpc-dev-router | Cloud Router for NAT |
| `google_compute_router_nat` | c4-vpc-dev-nat | Cloud NAT for egress |
| `google_compute_firewall` | c4-vpc-dev-allow-internal | Internal VPC traffic |
| `google_compute_firewall` | c4-vpc-dev-allow-http-https | HTTP/HTTPS ingress |
| `google_compute_firewall` | c4-vpc-dev-allow-health-checks | GCP health checks |
| `google_compute_firewall` | c4-vpc-dev-allow-ssh | SSH via IAP only |
| `google_compute_firewall` | c4-vpc-dev-deny-all-ingress | Default deny |
| `google_compute_global_address` | c4-vpc-dev-private-ip-range | Private service IP range |
| `google_service_networking_connection` | private_vpc_connection | Cloud SQL peering |

## Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_id` | GCP Project ID | - | Yes |
| `region` | GCP Region | - | Yes |
| `vpc_name` | VPC name | - | Yes |
| `subnet_cidr` | Main subnet CIDR | `10.0.0.0/20` | No |
| `pods_cidr` | Pods secondary range CIDR | `10.1.0.0/16` | No |
| `services_cidr` | Services secondary range CIDR | `10.2.0.0/20` | No |
| `labels` | Resource labels | `{}` | No |

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC network ID |
| `vpc_name` | VPC network name |
| `vpc_self_link` | VPC self link |
| `subnet_id` | Subnet ID |
| `subnet_name` | Subnet name |
| `pods_range_name` | Secondary range name for pods |
| `services_range_name` | Secondary range name for services |
| `router_name` | Cloud Router name |
| `nat_name` | Cloud NAT name |
| `private_vpc_connection` | Private service connection ID |

## Vérification des Ressources

### Script de Vérification Complet

```bash
#!/bin/bash
# verify-networking.sh - Verify all networking resources created by Terraform

PROJECT_ID="iac-rattrapage-epitech"
VPC_NAME="c4-vpc-dev"
REGION="europe-west1"

echo "=========================================="
echo "🔍 Vérification des ressources Networking"
echo "=========================================="

# 1. VPC Network
echo -e "\n📡 1. VPC Network"
gcloud compute networks describe $VPC_NAME \
  --project=$PROJECT_ID \
  --format="table(name,routingConfig.routingMode,autoCreateSubnetworks)" 2>/dev/null && \
  echo "✅ VPC exists" || echo "❌ VPC not found"

# 2. Subnet
echo -e "\n🔲 2. Subnet"
gcloud compute networks subnets describe ${VPC_NAME}-subnet \
  --region=$REGION \
  --project=$PROJECT_ID \
  --format="table(name,ipCidrRange,privateIpGoogleAccess,secondaryIpRanges[].rangeName)" 2>/dev/null && \
  echo "✅ Subnet exists" || echo "❌ Subnet not found"

# 3. Cloud Router
echo -e "\n🔀 3. Cloud Router"
gcloud compute routers describe ${VPC_NAME}-router \
  --region=$REGION \
  --project=$PROJECT_ID \
  --format="table(name,bgp.asn)" 2>/dev/null && \
  echo "✅ Router exists" || echo "❌ Router not found"

# 4. Cloud NAT
echo -e "\n🌐 4. Cloud NAT"
gcloud compute routers nats describe ${VPC_NAME}-nat \
  --router=${VPC_NAME}-router \
  --region=$REGION \
  --project=$PROJECT_ID \
  --format="table(name,natIpAllocateOption,sourceSubnetworkIpRangesToNat)" 2>/dev/null && \
  echo "✅ NAT exists" || echo "❌ NAT not found"

# 5. Firewall Rules
echo -e "\n🔥 5. Firewall Rules"
echo "Expected rules:"
for rule in "allow-internal" "allow-http-https" "allow-health-checks" "allow-ssh" "deny-all-ingress"; do
  gcloud compute firewall-rules describe ${VPC_NAME}-${rule} \
    --project=$PROJECT_ID \
    --format="value(name)" 2>/dev/null && \
    echo "  ✅ ${rule}" || echo "  ❌ ${rule} not found"
done

# 6. Private Service Connection
echo -e "\n🔗 6. Private Service Connection"
gcloud compute addresses describe ${VPC_NAME}-private-ip-range \
  --global \
  --project=$PROJECT_ID \
  --format="table(name,purpose,addressType,prefixLength)" 2>/dev/null && \
  echo "✅ Private IP range exists" || echo "❌ Private IP range not found"

# 7. Service Networking Connection
echo -e "\n🔌 7. VPC Peering (Service Networking)"
gcloud services vpc-peerings list \
  --network=$VPC_NAME \
  --project=$PROJECT_ID \
  --format="table(peering,network,reservedPeeringRanges)" 2>/dev/null && \
  echo "✅ VPC Peering exists" || echo "❌ VPC Peering not found"

echo -e "\n=========================================="
echo "✅ Vérification terminée"
echo "=========================================="
```

### Commandes Individuelles

#### VPC Network
```bash
# Vérifier le VPC
gcloud compute networks describe c4-vpc-dev \
  --project=iac-rattrapage-epitech

# Lister tous les VPCs
gcloud compute networks list --project=iac-rattrapage-epitech
```

#### Subnet
```bash
# Vérifier le subnet avec les ranges secondaires
gcloud compute networks subnets describe c4-vpc-dev-subnet \
  --region=europe-west1 \
  --project=iac-rattrapage-epitech

# Vérifier les secondary ranges
gcloud compute networks subnets describe c4-vpc-dev-subnet \
  --region=europe-west1 \
  --project=iac-rattrapage-epitech \
  --format="yaml(secondaryIpRanges)"
```

#### Cloud NAT
```bash
# Vérifier le routeur
gcloud compute routers describe c4-vpc-dev-router \
  --region=europe-west1 \
  --project=iac-rattrapage-epitech

# Vérifier le NAT
gcloud compute routers nats describe c4-vpc-dev-nat \
  --router=c4-vpc-dev-router \
  --region=europe-west1 \
  --project=iac-rattrapage-epitech
```

#### Firewall Rules
```bash
# Lister toutes les règles firewall du VPC
gcloud compute firewall-rules list \
  --filter="network:c4-vpc-dev" \
  --project=iac-rattrapage-epitech \
  --format="table(name,direction,priority,sourceRanges.list():label=SRC_RANGES,allowed[].map().firewall_rule().list():label=ALLOW)"

# Détail d'une règle spécifique
gcloud compute firewall-rules describe c4-vpc-dev-allow-internal \
  --project=iac-rattrapage-epitech
```

#### Private Service Connection
```bash
# Vérifier l'IP range réservée
gcloud compute addresses describe c4-vpc-dev-private-ip-range \
  --global \
  --project=iac-rattrapage-epitech

# Vérifier le peering
gcloud services vpc-peerings list \
  --network=c4-vpc-dev \
  --project=iac-rattrapage-epitech
```

### Résumé des Ressources Attendues

```bash
# Commande rapide pour compter les ressources
echo "=== Networking Resources Count ==="
echo "VPC Networks: $(gcloud compute networks list --filter='name:c4-vpc-dev' --format='value(name)' --project=iac-rattrapage-epitech | wc -l)"
echo "Subnets: $(gcloud compute networks subnets list --filter='name:c4-vpc-dev-subnet' --format='value(name)' --project=iac-rattrapage-epitech | wc -l)"
echo "Routers: $(gcloud compute routers list --filter='name:c4-vpc-dev-router' --format='value(name)' --project=iac-rattrapage-epitech | wc -l)"
echo "Firewall Rules: $(gcloud compute firewall-rules list --filter='network:c4-vpc-dev' --format='value(name)' --project=iac-rattrapage-epitech | wc -l)"
echo "Global Addresses: $(gcloud compute addresses list --global --filter='name:c4-vpc-dev-private-ip-range' --format='value(name)' --project=iac-rattrapage-epitech | wc -l)"
```

**Ressources attendues:**
| Type | Count |
|------|-------|
| VPC Network | 1 |
| Subnet | 1 |
| Cloud Router | 1 |
| Cloud NAT | 1 |
| Firewall Rules | 5 |
| Global Address | 1 |
| VPC Peering | 1 |
| **Total** | **11** |

## Sécurité

### Firewall Rules Explanation

| Rule | Source | Ports | Purpose |
|------|--------|-------|---------|
| `allow-internal` | VPC CIDRs | All | Pod-to-pod, node-to-node communication |
| `allow-http-https` | 0.0.0.0/0 | 80, 443 | Load Balancer ingress |
| `allow-health-checks` | GCP Health Check IPs | 8080, 10256 | LB health probes |
| `allow-ssh` | IAP Range only | 22 | Secure SSH via Identity-Aware Proxy |
| `deny-all-ingress` | 0.0.0.0/0 | All | Default deny (lowest priority) |

### Production Recommendations

1. **Restrict `allow-http-https`**: Add target tags to limit scope
2. **Remove `allow-ssh`**: Use IAP tunneling instead of firewall rule
3. **Add egress rules**: Control outbound traffic
4. **Enable VPC Flow Logs**: Already enabled with 50% sampling

## Troubleshooting

### NAT Issues
```bash
# Check NAT status
gcloud compute routers get-nat-mapping-info c4-vpc-dev-router \
  --region=europe-west1 \
  --project=iac-rattrapage-epitech

# Check NAT logs
gcloud logging read 'resource.type="nat_gateway"' \
  --project=iac-rattrapage-epitech \
  --limit=10
```

### Connectivity Issues
```bash
# Test from a VM in the VPC
gcloud compute ssh VM_NAME --tunnel-through-iap -- curl -v https://google.com

# Check firewall rule hits
gcloud compute firewall-rules describe c4-vpc-dev-allow-internal \
  --project=iac-rattrapage-epitech \
  --format="value(logConfig)"
```

## Références

- [VPC Networks](https://cloud.google.com/vpc/docs/vpc)
- [Cloud NAT](https://cloud.google.com/nat/docs/overview)
- [Firewall Rules](https://cloud.google.com/vpc/docs/firewalls)
- [Private Service Connection](https://cloud.google.com/vpc/docs/private-services-access)

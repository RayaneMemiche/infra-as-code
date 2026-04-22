# Plan de Défense C4 - Infrastructure as Code

## 📋 Structure de la Présentation

### 1. Introduction (2-3 min)
- Présentation de l'équipe
- Objectif du projet: Architecture Cloud-Native avec K8s, Helm & Identity Federation
- Stack technique: GCP, Terraform, Kubernetes, Helm, GitHub Actions

---

### 2. Architecture Infrastructure (5-7 min)

**Points à couvrir:**
- Présenter le diagramme d'architecture
- Expliquer chaque composant:
  - VPC `c4-vpc-dev` (10.0.0.0/20)
  - Subnets (pods: 10.1.0.0/16, services: 10.2.0.0/20)
  - Cloud NAT pour l'accès sortant
  - GKE Cluster `c4-cluster-dev` avec 3 node pools (application, runners, monitoring)
  - Cloud SQL PostgreSQL (private IP)
  - Workload Identity Federation

**Questions anticipées:**
- "Pourquoi des nodes privés?" → Sécurité, pas d'IP publique sur les nodes
- "Pourquoi Cloud NAT?" → Permet aux pods privés d'accéder à internet
- "Pourquoi séparer les node pools?" → Isolation des workloads, scaling indépendant

---

### 3. Identity Federation (3-5 min)

**Flow à expliquer:**
```
GitHub Actions → OIDC Token → GCP Workload Identity Pool → Temporary Credentials → GCP APIs
```

**Points clés:**
- Pas de credentials long-lived (pas de clés JSON)
- Token validé par GCP (vérifie le repo + environment)
- Credentials temporaires (1h max)
- Least privilege (chaque SA a ses propres rôles)

**Fichiers à montrer:**
- `modules/identity-federation/main.tf`
- `.github/workflows/terraform-apply.yml` (section WIF auth)

---

### 4. Application Task Manager (5-7 min)

**Démo live suggérée:**
```bash
# Port-forward pour accéder à l'API
kubectl port-forward svc/task-manager-api -n task-manager 8080:80

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl -H "Authorization: Bearer <token>" http://localhost:8080/tasks
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","content":"Demo","due_date":"2025-12-31"}' \
  http://localhost:8080/tasks
```

**Points à couvrir:**
- Architecture stateless
- Tous les HTTP codes (200, 201, 400, 401, 404, 409, 429, 500)
- Authentication Bearer token
- Rate limiting
- correlation_id pour le tracing
- request_timestamp pour l'ordering

---

### 5. Helm Charts (3-5 min)

**Charts à présenter:**
1. `helm/runners/` - Self-hosted GitHub Actions runners
2. `helm/task-manager-api/` - Application
3. `helm/monitoring/` - Prometheus + Grafana stack

**Points clés:**
- values.yaml pour configuration
- HPA pour auto-scaling
- Probes (startup, liveness, readiness)
- Security context (non-root, read-only)
- Workload Identity annotation

---

### 6. CI/CD Pipeline (5-7 min)

**Workflow à démontrer:**
```
Code Change → PR → terraform validate/plan → Merge → terraform apply (dev) → Tag → apply (prd)
```

**Workflows à expliquer:**
| Workflow | Trigger | Action |
|----------|---------|--------|
| terraform-validate | PR | fmt + validate |
| terraform-plan | PR | Plan dev + prd |
| terraform-apply | Tag/Push main | Apply dev puis prd |
| build-push-app | Push main/develop | Build & Push Docker |
| terraform-destroy | Manual | Destroy env |

**Points clés:**
- GitHub Environments (dev/prd)
- Protection rules sur prd
- Pas de secrets hardcodés (WIF + Secret Manager)

---

### 7. Monitoring & Observabilité (3-5 min)

**Stack:**
- Prometheus → Métriques
- Grafana → Dashboards & Alertes
- kube-state-metrics → Métriques K8s
- node-exporter → Métriques système

**Alertes configurées:**
- High CPU/Memory usage
- HPA maxed out
- Pod crash looping
- High request latency
- High error rate
- Runner pod resources

**Démo suggérée:**
```bash
# Accéder à Grafana
kubectl port-forward svc/c4-monitoring-grafana -n monitoring 3000:80
# Login: admin / <password>
```

---

### 8. Sécurité (2-3 min)

**Points à couvrir:**
- Firewall rules (deny all par défaut)
- SSH uniquement via IAP
- Nodes privés (pas d'IP publique)
- Workload Identity (pas de clés JSON)
- Secret Manager (pas de secrets en clair)
- Pod Security Context (non-root, read-only)
- Network policies ready (code présent)

---

### 9. Scalabilité & Coûts (2-3 min)

**Auto-scaling:**
- HPA sur l'application (1-10 replicas)
- Cluster Autoscaler (1-5 nodes)
- Runners auto-scale (1-5 replicas)

**Optimisations coûts:**
- Nodes preemptible en dev
- Scale to 0 sur runners pool
- db-f1-micro pour dev
- Monitoring pool supprimé (économie ~800m CPU)

---

### 10. Q&A (5-10 min)

**Questions probables:**
1. "Comment gérez-vous les secrets?" → External Secrets Operator + GCP Secret Manager
2. "Que se passe-t-il si un pod crash?" → Liveness probe restart, HPA scale up
3. "Comment rollback?" → `helm rollback` ou `terraform apply` avec ancien tag
4. "Justifiez votre choix de langage" → Node.js: léger, async I/O, bon pour API REST
5. "Comment gérez-vous les requêtes out-of-order?" → request_timestamp dans le body

---

## 📁 Fichiers Clés à Connaître

| Fichier | Contenu |
|---------|---------|
| `C4/infrastructure/main.tf` | Orchestration des modules |
| `C4/infrastructure/modules/gke/main.tf` | Cluster + Node Pools |
| `C4/infrastructure/modules/networking/main.tf` | VPC + NAT + Firewall |
| `C4/infrastructure/modules/identity-federation/main.tf` | WIF |
| `C4/infrastructure/modules/database/main.tf` | Cloud SQL |
| `C4/infrastructure/modules/monitoring/main.tf` | Monitoring stack |
| `task-manager-api/src/index.js` | API Express |
| `.github/workflows/terraform-apply.yml` | CI/CD principal |

---

## 🔥 Load Testing Demo (Locust)

**Objectif:** Valider la scalabilite de l'infrastructure sous charge.

**Outil:** [Locust](https://locust.io/) - Load testing framework en Python.

**Demo live suggeree:**
```bash
# Lancer Locust en local (pointer vers l'API)
cd load-testing
pip install locust
locust -f locustfile.py --host=http://localhost:8080

# Ouvrir l'interface web Locust
# http://localhost:8089
```

**Points a couvrir:**
- Scenarios de charge: creation de taches, lecture, authentification
- Observer le HPA scale-up en temps reel: `kubectl get hpa -n task-manager -w`
- Observer les metriques dans Grafana pendant le test
- Montrer le Cluster Autoscaler reagir si la charge est suffisante
- Valider le rate limiting (429 Too Many Requests)

**Metriques a surveiller:**
- Latence p95/p99
- Taux d'erreur
- Nombre de replicas (HPA)
- CPU/Memory des pods

---

## 🎯 Checklist Avant Défense

- [ ] Diagramme d'architecture imprimé/affiché
- [ ] Cluster GKE running
- [ ] Application deployed et accessible
- [ ] Pouvoir montrer les logs/métriques
- [ ] Connaître les commandes kubectl de base
- [ ] Savoir expliquer chaque composant du diagramme
- [ ] Préparer les réponses aux questions fréquentes

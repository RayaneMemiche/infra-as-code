# C4 Architecture Diagram

## Diagramme Principal (Mermaid)

```mermaid
flowchart TB
    subgraph INTERNET["☁️ Internet"]
        USER["👤 Users"]
        GITHUB["🐙 GitHub Actions"]
    end

    subgraph GCP["Google Cloud Platform (europe-west1)"]

        subgraph WIF["🔐 Workload Identity Federation"]
            POOL["github-pool"]
            PROVIDER["github-provider"]
            SA_TF["terraform-github-actions SA"]
        end

        subgraph VPC["🌐 VPC: c4-vpc-dev (10.0.0.0/20)"]

            subgraph PUBLIC["Zone Publique"]
                LB["⚖️ Load Balancer"]
                NAT["🌍 Cloud NAT"]
            end

            subgraph GKE["☸️ GKE Cluster: c4-cluster-dev"]

                subgraph APP_POOL["📦 Application Node Pool (1-5 nodes)"]
                    subgraph NS_TM["Namespace: task-manager"]
                        API["🚀 Task Manager API"]
                        HPA_APP["📈 HPA (1-10 replicas)"]
                        ESO_SECRET["🔑 ExternalSecret"]
                    end

                    subgraph NS_MON["Namespace: monitoring"]
                        PROM["📊 Prometheus"]
                        GRAF["📈 Grafana"]
                        ALERT["🔔 Alertmanager"]
                    end

                    subgraph NS_ESO["Namespace: external-secrets"]
                        ESO["🔐 External Secrets Operator"]
                        CSS["ClusterSecretStore"]
                    end
                end

                subgraph RUNNER_POOL["🏃 Runners Node Pool (0-2 nodes)"]
                    subgraph NS_RUN["Namespace: runners"]
                        RUNNER["🤖 GitHub Runners"]
                        HPA_RUN["📈 HPA (1-5 replicas)"]
                    end
                end
            end

            subgraph DATA["💾 Data Layer"]
                SQL["🐘 Cloud SQL PostgreSQL<br/>c4-postgres-dev<br/>(Private IP)"]
            end
        end

        subgraph SECRETS["🔒 Secret Manager"]
            DB_PASS["db-password"]
            DB_URL["database-url"]
        end

        subgraph AR["📦 Artifact Registry"]
            IMAGES["task-manager-api images"]
        end
    end

    %% Connexions
    USER -->|HTTPS| LB
    LB -->|HTTP:80| API
    API -->|TCP:5432| SQL

    GITHUB -->|OIDC Token| POOL
    POOL --> PROVIDER
    PROVIDER -->|Temporary Credentials| SA_TF
    SA_TF -->|Deploy| GKE
    SA_TF -->|Push| AR

    ESO -->|Fetch| SECRETS
    ESO --> CSS
    CSS --> ESO_SECRET
    ESO_SECRET -->|Inject| API

    API -->|Outbound| NAT
    NAT -->|Internet Access| INTERNET

    PROM -->|Scrape| API
    PROM -->|Scrape| RUNNER

    RUNNER -->|Pull| AR
    API -.->|Image| AR

    %% Styles
    classDef gcp fill:#4285f4,color:white
    classDef k8s fill:#326ce5,color:white
    classDef security fill:#ea4335,color:white
    classDef data fill:#34a853,color:white
    classDef monitoring fill:#fbbc04,color:black

    class GCP,VPC gcp
    class GKE,APP_POOL,RUNNER_POOL k8s
    class WIF,SECRETS,ESO security
    class SQL,AR data
    class PROM,GRAF,ALERT monitoring
```

---

## Diagramme Simplifié (Pour Présentation)

```mermaid
flowchart LR
    subgraph EXTERNAL["External"]
        A["👤 Users"]
        B["🐙 GitHub"]
    end

    subgraph GCP["GCP europe-west1"]
        C["⚖️ Load Balancer"]
        D["☸️ GKE Cluster"]
        E["🐘 Cloud SQL"]
        F["🔐 WIF"]
        G["🔒 Secrets"]
    end

    A -->|HTTPS| C
    C --> D
    D <--> E
    B -->|OIDC| F
    F -->|Deploy| D
    G -->|Inject| D

    style GCP fill:#e8f0fe
    style D fill:#326ce5,color:white
    style F fill:#ea4335,color:white
```

---

## Diagramme des Flux Réseau

```mermaid
flowchart TB
    subgraph INGRESS["📥 Ingress Traffic"]
        USER["Users (Internet)"]
    end

    subgraph VPC["VPC: 10.0.0.0/20"]
        LB["Load Balancer<br/>(External IP)"]

        subgraph SUBNET["Subnet: 10.0.0.0/20"]
            subgraph PODS["Pod Range: 10.1.0.0/16"]
                API_POD["API Pods"]
                RUNNER_POD["Runner Pods"]
                MON_POD["Monitoring Pods"]
            end

            subgraph SERVICES["Service Range: 10.2.0.0/20"]
                API_SVC["api-service:80"]
                PROM_SVC["prometheus:9090"]
                GRAF_SVC["grafana:80"]
            end
        end

        NAT["Cloud NAT"]

        subgraph PRIVATE["Private Services"]
            SQL["Cloud SQL<br/>Private IP"]
        end
    end

    subgraph EGRESS["📤 Egress Traffic"]
        INTERNET["Internet<br/>(npm, Docker Hub, etc.)"]
    end

    USER -->|"HTTPS (443)"| LB
    LB -->|"HTTP (80)"| API_SVC
    API_SVC --> API_POD
    API_POD -->|"TCP (5432)"| SQL
    API_POD --> NAT
    RUNNER_POD --> NAT
    NAT --> INTERNET
    MON_POD -->|"Scrape (metrics)"| API_POD
    MON_POD -->|"Scrape (metrics)"| RUNNER_POD
```

---

## Diagramme Workload Identity Federation

```mermaid
sequenceDiagram
    participant GH as 🐙 GitHub Actions
    participant OIDC as 🔑 GitHub OIDC Provider
    participant WIF as 🛡️ GCP WIF Pool
    participant SA as 👤 Service Account
    participant GCP as ☁️ GCP APIs

    GH->>OIDC: 1. Request OIDC Token
    OIDC-->>GH: 2. JWT Token (repo, env, ref)
    GH->>WIF: 3. Exchange Token
    Note over WIF: Validate:<br/>- repo = Jouzep/infra-as-code<br/>- environment = dev/prd
    WIF->>SA: 4. Impersonate SA
    SA-->>GH: 5. Temporary Credentials (1h)
    GH->>GCP: 6. API Calls with temp creds
    Note over GCP: terraform apply<br/>kubectl deploy<br/>docker push
```

---

## Diagramme CI/CD Pipeline

```mermaid
flowchart LR
    subgraph DEV["👨‍💻 Development"]
        CODE["Code Change"]
        PR["Pull Request"]
    end

    subgraph CI["🔄 CI (GitHub Actions)"]
        VAL["terraform validate"]
        PLAN["terraform plan"]
        BUILD["docker build"]
    end

    subgraph CD["🚀 CD (GitHub Actions)"]
        APPLY_DEV["apply dev"]
        APPLY_PRD["apply prd"]
        PUSH["docker push"]
    end

    subgraph K8S["☸️ Kubernetes"]
        DEPLOY["Deployment"]
        RESTART["Rollout Restart"]
    end

    CODE --> PR
    PR --> VAL
    PR --> PLAN
    PR -->|Merge| BUILD
    BUILD --> PUSH
    PUSH --> APPLY_DEV
    APPLY_DEV -->|Tag| APPLY_PRD
    APPLY_DEV --> DEPLOY
    PUSH --> RESTART
    RESTART --> DEPLOY

    style CI fill:#f6f8fa
    style CD fill:#dafbe1
    style K8S fill:#326ce5,color:white
```

---

## Diagramme ASCII (Pour Terminal/Documentation)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                            │
│    ┌──────────┐                                      ┌──────────────────┐       │
│    │  Users   │                                      │  GitHub Actions  │       │
│    └────┬─────┘                                      └────────┬─────────┘       │
│         │ HTTPS                                               │ OIDC            │
└─────────┼─────────────────────────────────────────────────────┼─────────────────┘
          │                                                     │
          ▼                                                     ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         GCP (europe-west1)                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                    Workload Identity Federation                          │    │
│  │   github-pool ──► github-provider ──► terraform-github-actions SA       │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                      VPC: c4-vpc-dev (10.0.0.0/20)                       │    │
│  │                                                                          │    │
│  │   ┌──────────────┐     ┌────────────────────────────────────────────┐   │    │
│  │   │ Load Balancer│────►│         GKE: c4-cluster-dev                │   │    │
│  │   └──────────────┘     │  ┌──────────────────────────────────────┐  │   │    │
│  │                        │  │     Application Pool (1-5 nodes)     │  │   │    │
│  │                        │  │  ┌─────────────┐  ┌───────────────┐  │  │   │    │
│  │                        │  │  │ task-manager│  │  monitoring   │  │  │   │    │
│  │                        │  │  │  API (HPA)  │  │ Prom+Grafana  │  │  │   │    │
│  │                        │  │  └──────┬──────┘  └───────────────┘  │  │   │    │
│  │                        │  └─────────┼────────────────────────────┘  │   │    │
│  │                        │            │                               │   │    │
│  │                        │  ┌─────────┼────────────────────────────┐  │   │    │
│  │                        │  │     Runners Pool (0-2 nodes)         │  │   │    │
│  │                        │  │  ┌─────────────────────────────────┐ │  │   │    │
│  │                        │  │  │   GitHub Self-Hosted Runners    │ │  │   │    │
│  │                        │  │  └─────────────────────────────────┘ │  │   │    │
│  │                        │  └──────────────────────────────────────┘  │   │    │
│  │                        └────────────────────────────────────────────┘   │    │
│  │                                     │                                    │    │
│  │   ┌──────────────┐                  │ TCP:5432                          │    │
│  │   │  Cloud NAT   │◄─── Pods ────────┤                                   │    │
│  │   └──────┬───────┘                  ▼                                   │    │
│  │          │                 ┌─────────────────┐                          │    │
│  │          │                 │   Cloud SQL     │                          │    │
│  │          │                 │   PostgreSQL    │                          │    │
│  │          │                 │  (Private IP)   │                          │    │
│  │          │                 └─────────────────┘                          │    │
│  └──────────┼──────────────────────────────────────────────────────────────┘    │
│             │                                                                    │
│             ▼                                                                    │
│     ┌───────────────┐    ┌────────────────┐    ┌─────────────────┐             │
│     │Artifact Regis.│    │ Secret Manager │    │   IAM Roles     │             │
│     │  (Images)     │    │  (Passwords)   │    │ (Permissions)   │             │
│     └───────────────┘    └────────────────┘    └─────────────────┘             │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Légende des Composants

| Composant | Description | Configuration |
|-----------|-------------|---------------|
| **VPC** | Réseau isolé | 10.0.0.0/20, europe-west1 |
| **GKE Cluster** | Kubernetes managé | 2 node pools, Workload Identity |
| **Application Pool** | Nodes pour apps | e2-standard-2, 1-5 nodes, autoscaling |
| **Runners Pool** | Nodes pour CI/CD | e2-medium, 0-2 nodes, taint dedicated |
| **Cloud SQL** | PostgreSQL managé | db-f1-micro (dev), private IP, backups |
| **Cloud NAT** | Accès sortant | Pour pods sans IP publique |
| **Load Balancer** | Entrée externe | Service type LoadBalancer |
| **WIF** | Auth sans secrets | GitHub OIDC → GCP credentials |
| **ESO** | Sync secrets | GCP Secret Manager → K8s Secrets |
| **Prometheus** | Métriques | 15 jours retention, alertes |
| **Grafana** | Dashboards | Visualisation métriques |

---

## Comment Visualiser

### Option 1: Mermaid Live Editor
1. Aller sur https://mermaid.live/
2. Copier le code Mermaid
3. Exporter en PNG/SVG

### Option 2: VS Code
1. Installer extension "Markdown Preview Mermaid Support"
2. Ouvrir ce fichier en preview (Cmd+Shift+V)

### Option 3: GitHub
1. Push ce fichier sur GitHub
2. Les diagrammes Mermaid sont rendus automatiquement

### Option 4: Draw.io
1. Aller sur https://app.diagrams.net/
2. Utiliser le diagramme ASCII comme référence
3. Créer manuellement avec les icônes GCP

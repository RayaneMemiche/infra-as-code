#!/bin/bash
# =============================================================================
# Setup Kubernetes Secrets for Task Manager API
# C4 Project - Secret Management Helper
# =============================================================================

set -e

# Configuration
NAMESPACE="${NAMESPACE:-task-manager}"
SECRET_NAME="${SECRET_NAME:-task-manager-api-secrets}"
CLUSTER_NAME="${CLUSTER_NAME:-c4-cluster-dev}"
REGION="${REGION:-europe-west1}"
PROJECT_ID="${PROJECT_ID:-fourth-outpost-479614-t4}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Task Manager API - Secret Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check required tools
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}Error: kubectl is required${NC}"; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo -e "${RED}Error: gcloud is required${NC}"; exit 1; }

# Get GKE credentials
echo -e "${YELLOW}Getting GKE credentials...${NC}"
gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region "$REGION" \
    --project "$PROJECT_ID"

# Create namespace if not exists
echo -e "${YELLOW}Creating namespace if not exists...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Check if secret already exists
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" 2>/dev/null; then
    echo -e "${YELLOW}Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'${NC}"
    read -p "Do you want to update it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Keeping existing secret. Done!${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Updating existing secret...${NC}"
    kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
fi

# Prompt for secret values
echo ""
echo -e "${YELLOW}Enter secret values:${NC}"
echo ""

# DATABASE_URL
echo "DATABASE_URL format: postgresql://user:password@host:port/database"
read -p "DATABASE_URL: " DATABASE_URL
if [ -z "$DATABASE_URL" ]; then
    echo -e "${RED}Error: DATABASE_URL is required${NC}"
    exit 1
fi

# API_TOKEN
echo ""
echo "API_TOKEN: Bearer token for API authentication"
read -p "API_TOKEN (leave empty to generate): " API_TOKEN
if [ -z "$API_TOKEN" ]; then
    API_TOKEN=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
    echo -e "${GREEN}Generated API_TOKEN: $API_TOKEN${NC}"
fi

# Create secret
echo ""
echo -e "${YELLOW}Creating secret '$SECRET_NAME' in namespace '$NAMESPACE'...${NC}"

kubectl create secret generic "$SECRET_NAME" \
    --namespace "$NAMESPACE" \
    --from-literal=DATABASE_URL="$DATABASE_URL" \
    --from-literal=API_TOKEN="$API_TOKEN"

# Verify
echo ""
echo -e "${GREEN}Secret created successfully!${NC}"
echo ""
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Deploy the application:"
echo "     helm upgrade --install task-manager-api ./C4/infrastructure/helm/task-manager-api \\"
echo "       --namespace $NAMESPACE \\"
echo "       --values ./C4/infrastructure/helm/task-manager-api/values-dev.yaml"
echo ""
echo "  2. Or trigger the GitHub Actions workflow:"
echo "     gh workflow run deploy-app.yml -f environment=dev"
echo ""

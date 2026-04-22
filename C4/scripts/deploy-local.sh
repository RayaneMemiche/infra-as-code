#!/bin/bash
# =============================================================================
# Local Deployment Script for Task Manager API
# C4 Project - Quick local deployment helper
# =============================================================================

set -e

# Configuration
NAMESPACE="${NAMESPACE:-task-manager}"
RELEASE_NAME="${RELEASE_NAME:-task-manager-api}"
CHART_PATH="${CHART_PATH:-./C4/infrastructure/helm/task-manager-api}"
ENVIRONMENT="${1:-dev}"
IMAGE_TAG="${2:-dev}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} Task Manager API - Local Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Environment: ${GREEN}$ENVIRONMENT${NC}"
echo -e "Image Tag:   ${GREEN}$IMAGE_TAG${NC}"
echo ""

# Check required tools
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}Error: kubectl is required${NC}"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}Error: helm is required${NC}"; exit 1; }

# Check kubectl context
echo -e "${YELLOW}Current kubectl context:${NC}"
kubectl config current-context
echo ""

# Check if secrets exist
echo -e "${YELLOW}Checking secrets...${NC}"
if ! kubectl get secret task-manager-api-secrets -n "$NAMESPACE" 2>/dev/null; then
    echo -e "${RED}Error: Secret 'task-manager-api-secrets' not found in namespace '$NAMESPACE'${NC}"
    echo -e "${YELLOW}Run: ./C4/scripts/setup-secrets.sh${NC}"
    exit 1
fi
echo -e "${GREEN}Secrets found!${NC}"
echo ""

# Deploy with Helm
echo -e "${YELLOW}Deploying with Helm...${NC}"
helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --values "$CHART_PATH/values-$ENVIRONMENT.yaml" \
    --set image.tag="$IMAGE_TAG" \
    --wait \
    --timeout 5m

echo ""
echo -e "${YELLOW}Waiting for rollout...${NC}"
kubectl rollout status deployment/"$RELEASE_NAME" \
    --namespace "$NAMESPACE" \
    --timeout=300s

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Show status
echo -e "${YELLOW}Deployment Status:${NC}"
kubectl get pods,svc,hpa -n "$NAMESPACE" -l app.kubernetes.io/name=task-manager-api
echo ""

# Access instructions
echo -e "${BLUE}Access the API:${NC}"
echo ""
echo "  # Port forward to local machine"
echo "  kubectl port-forward svc/$RELEASE_NAME 8080:80 -n $NAMESPACE"
echo ""
echo "  # Test health endpoint"
echo "  curl http://localhost:8080/health"
echo ""
echo "  # Test ready endpoint"
echo "  curl http://localhost:8080/ready"
echo ""
echo "  # Test tasks endpoint (requires auth)"
echo "  curl -H 'Authorization: Bearer YOUR_API_TOKEN' http://localhost:8080/tasks"
echo ""

#!/bin/bash
# ============================================================================
# Monitoring Stack Deployment Script
# ============================================================================
# This script deploys the complete monitoring stack including:
# - Prometheus for metrics collection
# - Grafana for visualization
# - Alertmanager for alerting
# - ServiceMonitors for Argo Rollouts
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="monitoring"
HELM_RELEASE_NAME="monitoring"
PROMETHEUS_STACK_VERSION="51.0.0"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying Monitoring Stack${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

# Add Prometheus Community Helm repo
echo -e "${YELLOW}Adding Prometheus Community Helm repository...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace if it doesn't exist
echo -e "${YELLOW}Creating monitoring namespace...${NC}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Install/Upgrade Prometheus Stack
echo -e "${YELLOW}Installing/Upgrading Prometheus Stack...${NC}"
helm upgrade --install ${HELM_RELEASE_NAME} \
    prometheus-community/kube-prometheus-stack \
    --namespace ${NAMESPACE} \
    --version ${PROMETHEUS_STACK_VERSION} \
    --values k8s/monitoring/monitoring-values.yaml \
    --wait \
    --timeout 10m

# Apply custom Prometheus rules
echo -e "${YELLOW}Applying custom Prometheus rules...${NC}"
kubectl apply -f k8s/monitoring/prometheus.yaml

# Wait for all pods to be ready
echo -e "${YELLOW}Waiting for monitoring stack pods to be ready...${NC}"
kubectl wait --for=condition=ready pod \
    -l "release=${HELM_RELEASE_NAME}" \
    -n ${NAMESPACE} \
    --timeout=300s || true

# Get Grafana admin password
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Monitoring Stack Deployed Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

# Display access information
echo -e "\n${YELLOW}Access Information:${NC}"
echo -e "${GREEN}Prometheus:${NC}"
kubectl get svc -n ${NAMESPACE} | grep prometheus-server || true
echo -e "\n${GREEN}Grafana:${NC}"
kubectl get svc -n ${NAMESPACE} | grep grafana || true
echo -e "\n${GREEN}Alertmanager:${NC}"
kubectl get svc -n ${NAMESPACE} | grep alertmanager || true

echo -e "\n${YELLOW}To access Grafana locally:${NC}"
echo -e "kubectl port-forward -n ${NAMESPACE} svc/${HELM_RELEASE_NAME}-grafana 3000:80"
echo -e "\n${YELLOW}Default Grafana credentials:${NC}"
echo -e "Username: admin"
echo -e "Password: Run 'kubectl get secret -n ${NAMESPACE} ${HELM_RELEASE_NAME}-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode'"

echo -e "\n${YELLOW}To access Prometheus locally:${NC}"
echo -e "kubectl port-forward -n ${NAMESPACE} svc/${HELM_RELEASE_NAME}-kube-prometheus-prometheus 9090:9090"

echo -e "\n${GREEN}Deployment complete!${NC}"

#!/bin/bash
# ============================================================================
# Complete Infrastructure Deployment Script
# ============================================================================
# This script orchestrates the complete deployment of the zero-downtime
# infrastructure including Terraform, Kubernetes resources, and monitoring
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT"
K8S_DIR="$PROJECT_ROOT/k8s"

# Default values
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-zdd-eks-production}"
SKIP_TERRAFORM="${SKIP_TERRAFORM:-false}"
SKIP_MONITORING="${SKIP_MONITORING:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check required tools
    for tool in terraform kubectl helm aws; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
            print_error "$tool is not installed"
        else
            print_success "$tool is installed"
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Please install missing tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    print_success "AWS credentials configured"
    
    # Check Terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    print_success "Terraform version: $TERRAFORM_VERSION"
}

deploy_terraform() {
    print_header "Deploying Terraform Infrastructure"
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    print_warning "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    print_warning "Validating Terraform configuration..."
    terraform validate
    
    if [ "$DRY_RUN" = "true" ]; then
        print_warning "Running Terraform plan (dry run)..."
        terraform plan
        return 0
    fi
    
    # Plan
    print_warning "Creating Terraform plan..."
    terraform plan -out=tfplan
    
    # Apply
    read -p "Do you want to apply this plan? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        print_warning "Applying Terraform configuration..."
        terraform apply tfplan
        rm tfplan
        print_success "Terraform infrastructure deployed"
    else
        print_warning "Terraform apply cancelled"
        exit 0
    fi
}

configure_kubectl() {
    print_header "Configuring kubectl"
    
    print_warning "Updating kubeconfig for EKS cluster..."
    aws eks update-kubeconfig \
        --region "$AWS_REGION" \
        --name "$CLUSTER_NAME"
    
    # Verify connection
    print_warning "Verifying cluster connection..."
    kubectl cluster-info
    kubectl get nodes
    
    print_success "kubectl configured successfully"
}

deploy_monitoring() {
    print_header "Deploying Monitoring Stack"
    
    cd "$PROJECT_ROOT"
    
    if [ -f "scripts/deploy-monitoring.sh" ]; then
        chmod +x scripts/deploy-monitoring.sh
        ./scripts/deploy-monitoring.sh
        print_success "Monitoring stack deployed"
    else
        print_warning "Monitoring deployment script not found"
    fi
}

deploy_demo_apps() {
    print_header "Deploying Demo Applications"
    
    cd "$K8S_DIR"
    
    # Deploy blue-green application
    print_warning "Deploying blue-green application..."
    kubectl apply -f blue-green/rollout.yaml
    
    # Deploy canary application
    print_warning "Deploying canary application..."
    kubectl apply -f canary/rollout.yaml
    
    print_success "Demo applications deployed"
}

verify_deployment() {
    print_header "Verifying Deployment"
    
    print_warning "Checking cluster resources..."
    
    # Check nodes
    echo -e "\n${YELLOW}Cluster Nodes:${NC}"
    kubectl get nodes
    
    # Check namespaces
    echo -e "\n${YELLOW}Namespaces:${NC}"
    kubectl get namespaces
    
    # Check pods in all namespaces
    echo -e "\n${YELLOW}All Pods:${NC}"
    kubectl get pods --all-namespaces
    
    # Check rollouts
    echo -e "\n${YELLOW}Argo Rollouts:${NC}"
    kubectl get rollouts -n applications
    
    # Check services
    echo -e "\n${YELLOW}Services:${NC}"
    kubectl get svc --all-namespaces
    
    # Check ingresses
    echo -e "\n${YELLOW}Ingresses:${NC}"
    kubectl get ingress --all-namespaces
    
    print_success "Deployment verification complete"
}

print_access_info() {
    print_header "Access Information"
    
    echo -e "${GREEN}Cluster Information:${NC}"
    echo -e "Cluster Name: ${CLUSTER_NAME}"
    echo -e "Region: ${AWS_REGION}"
    echo -e "Kubeconfig: ~/.kube/config"
    
    echo -e "\n${GREEN}Grafana Access:${NC}"
    echo -e "Port forward: kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"
    echo -e "URL: http://localhost:3000"
    echo -e "Username: admin"
    echo -e "Password: kubectl get secret -n monitoring monitoring-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode"
    
    echo -e "\n${GREEN}Prometheus Access:${NC}"
    echo -e "Port forward: kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
    echo -e "URL: http://localhost:9090"
    
    echo -e "\n${GREEN}Argo Rollouts Dashboard:${NC}"
    echo -e "Port forward: kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100"
    echo -e "URL: http://localhost:3100"
    
    echo -e "\n${GREEN}Useful Commands:${NC}"
    echo -e "List rollouts: kubectl argo rollouts list rollouts -A"
    echo -e "Watch rollout: kubectl argo rollouts get rollout <name> -n applications --watch"
    echo -e "Promote rollout: kubectl argo rollouts promote <name> -n applications"
    echo -e "Abort rollout: kubectl argo rollouts abort <name> -n applications"
}

# Main execution
main() {
    print_header "Zero-Downtime Deployment - Infrastructure Setup"
    
    check_prerequisites
    
    if [ "$SKIP_TERRAFORM" != "true" ]; then
        deploy_terraform
        sleep 10  # Wait for resources to stabilize
    else
        print_warning "Skipping Terraform deployment"
    fi
    
    configure_kubectl
    
    if [ "$SKIP_MONITORING" != "true" ]; then
        deploy_monitoring
    else
        print_warning "Skipping monitoring deployment"
    fi
    
    # Wait for core services
    print_warning "Waiting for core services to be ready..."
    sleep 30
    
    deploy_demo_apps
    
    verify_deployment
    
    print_access_info
    
    print_header "Deployment Complete! 🎉"
    echo -e "${GREEN}Your zero-downtime deployment infrastructure is ready!${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        --skip-monitoring)
            SKIP_MONITORING=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-terraform     Skip Terraform deployment"
            echo "  --skip-monitoring    Skip monitoring stack deployment"
            echo "  --dry-run            Run in dry-run mode (Terraform plan only)"
            echo "  --region REGION      AWS region (default: us-east-1)"
            echo "  --cluster-name NAME  EKS cluster name (default: zdd-eks-production)"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main

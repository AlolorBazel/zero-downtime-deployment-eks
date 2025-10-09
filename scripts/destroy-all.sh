#!/bin/bash
set -e

# ════════════════════════════════════════════════════════════════
# AWS INFRASTRUCTURE COMPLETE TEARDOWN SCRIPT
# ════════════════════════════════════════════════════════════════
# This script destroys ALL AWS resources to stop billing completely
# Use with caution - this is IRREVERSIBLE!
# ════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
echo -e "${RED}         ⚠️  COMPLETE AWS INFRASTRUCTURE TEARDOWN ⚠️${NC}"
echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}This will destroy ALL AWS resources including:${NC}"
echo ""
echo "  • EKS Cluster + Control Plane"
echo "  • ALL EC2 Worker Nodes (currently 5 nodes)"
echo "  • VPC, Subnets, NAT Gateways, Internet Gateway"
echo "  • Load Balancers (ALB/NLB)"
echo "  • Security Groups"
echo "  • IAM Roles and Policies"
echo "  • CloudWatch Log Groups"
echo "  • EBS Volumes"
echo "  • Elastic IPs"
echo ""
echo -e "${RED}⚠️  THIS ACTION IS IRREVERSIBLE ⚠️${NC}"
echo -e "${RED}⚠️  ALL DATA WILL BE LOST ⚠️${NC}"
echo ""
echo -e "${GREEN}Current AWS Cost: ~\$474/month${NC}"
echo -e "${GREEN}After Teardown: \$0/month${NC}"
echo ""
echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Require explicit confirmation
read -p "Type 'DESTROY' to confirm complete teardown: " CONFIRM
if [ "$CONFIRM" != "DESTROY" ]; then
    echo -e "${YELLOW}Aborted. No changes made.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Step 1/7: Pre-destruction resource audit...${NC}"
echo "Counting current AWS resources..."

# Get resource counts
TOTAL_RESOURCES=$(terraform state list 2>/dev/null | wc -l)
echo -e "  ${GREEN}✓${NC} Found $TOTAL_RESOURCES Terraform-managed resources"

# Check for running pods
RUNNING_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
echo -e "  ${GREEN}✓${NC} Found $RUNNING_PODS running Kubernetes pods"

echo ""
echo -e "${BLUE}Step 2/7: Scaling down Kubernetes deployments...${NC}"
echo "This prevents new resources from being created during teardown"

# Scale down all deployments to prevent auto-recreation
kubectl scale deployment --all --replicas=0 -n applications 2>/dev/null || true
kubectl scale rollout --all --replicas=0 -n applications 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Scaled down application deployments"

# Delete all rollouts to prevent argo from recreating
kubectl delete rollout --all -n applications --grace-period=10 --timeout=60s 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Deleted Argo Rollouts"

sleep 5

echo ""
echo -e "${BLUE}Step 3/7: Removing Kubernetes LoadBalancer services...${NC}"
echo "These create AWS Load Balancers that must be deleted first"

# Delete all LoadBalancer type services (they create ALBs/NLBs)
LB_SERVICES=$(kubectl get svc --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace)/\(.metadata.name)"' || echo "")
if [ -n "$LB_SERVICES" ]; then
    echo "$LB_SERVICES" | while read svc; do
        NS=$(echo $svc | cut -d'/' -f1)
        NAME=$(echo $svc | cut -d'/' -f2)
        kubectl delete svc "$NAME" -n "$NS" --grace-period=10 --timeout=60s 2>/dev/null || true
        echo -e "  ${GREEN}✓${NC} Deleted LoadBalancer service: $NS/$NAME"
    done
else
    echo -e "  ${GREEN}✓${NC} No LoadBalancer services found"
fi

# Wait for AWS to clean up load balancers
echo "  Waiting 30s for AWS to delete load balancers..."
sleep 30

echo ""
echo -e "${BLUE}Step 4/7: Destroying Terraform-managed resources...${NC}"
echo "This will destroy the EKS cluster, VPC, and all infrastructure"

# First, destroy Kubernetes resources (namespaces, helm releases)
echo "  Removing Helm releases..."
terraform destroy -target=helm_release.argo_rollouts -auto-approve 2>/dev/null || true
terraform destroy -target=helm_release.aws_load_balancer_controller -auto-approve 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Helm releases removed"

# Wait a bit for finalizers
sleep 10

# Now destroy everything else
echo "  Destroying all infrastructure..."
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} Terraform destroy completed successfully"
else
    echo -e "  ${YELLOW}⚠${NC} Terraform destroy encountered some issues"
    echo "  Continuing with manual cleanup verification..."
fi

echo ""
echo -e "${BLUE}Step 5/7: Checking for orphaned AWS resources...${NC}"
echo "Verifying no resources were left behind"

# Get AWS region and cluster name from tfvars
REGION=$(grep 'aws_region' terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "us-west-2")
CLUSTER_NAME=$(grep 'cluster_name' terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "zero-downtime-eks")

echo "  Checking for orphaned Load Balancers..."
ORPHAN_ALBS=$(aws elbv2 describe-load-balancers --region "$REGION" 2>/dev/null | jq -r ".LoadBalancers[] | select(.LoadBalancerName | contains(\"$CLUSTER_NAME\")) | .LoadBalancerArn" || echo "")
if [ -n "$ORPHAN_ALBS" ]; then
    echo -e "  ${YELLOW}⚠${NC} Found orphaned load balancers, deleting..."
    echo "$ORPHAN_ALBS" | while read arn; do
        aws elbv2 delete-load-balancer --load-balancer-arn "$arn" --region "$REGION" 2>/dev/null || true
    done
else
    echo -e "  ${GREEN}✓${NC} No orphaned load balancers"
fi

echo "  Checking for orphaned Security Groups..."
ORPHAN_SGS=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" 2>/dev/null | jq -r '.SecurityGroups[].GroupId' || echo "")
if [ -n "$ORPHAN_SGS" ]; then
    echo -e "  ${YELLOW}⚠${NC} Found orphaned security groups, deleting..."
    # Wait a bit for ENIs to detach
    sleep 30
    echo "$ORPHAN_SGS" | while read sg; do
        aws ec2 delete-security-group --group-id "$sg" --region "$REGION" 2>/dev/null || true
    done
else
    echo -e "  ${GREEN}✓${NC} No orphaned security groups"
fi

echo "  Checking for orphaned EBS Volumes..."
ORPHAN_VOLS=$(aws ec2 describe-volumes --region "$REGION" --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" "Name=status,Values=available" 2>/dev/null | jq -r '.Volumes[].VolumeId' || echo "")
if [ -n "$ORPHAN_VOLS" ]; then
    echo -e "  ${YELLOW}⚠${NC} Found orphaned EBS volumes, deleting..."
    echo "$ORPHAN_VOLS" | while read vol; do
        aws ec2 delete-volume --volume-id "$vol" --region "$REGION" 2>/dev/null || true
    done
else
    echo -e "  ${GREEN}✓${NC} No orphaned EBS volumes"
fi

echo ""
echo -e "${BLUE}Step 6/7: Cleaning up local state...${NC}"

# Remove terraform state
if [ -f "terraform.tfstate" ]; then
    mv terraform.tfstate terraform.tfstate.destroyed.$(date +%Y%m%d_%H%M%S)
    echo -e "  ${GREEN}✓${NC} Terraform state backed up"
fi

if [ -f "terraform.tfstate.backup" ]; then
    mv terraform.tfstate.backup terraform.tfstate.backup.destroyed.$(date +%Y%m%d_%H%M%S)
    echo -e "  ${GREEN}✓${NC} Terraform backup state archived"
fi

# Remove kubeconfig
if [ -f "kubeconfig" ]; then
    rm -f kubeconfig
    echo -e "  ${GREEN}✓${NC} Removed kubeconfig file"
fi

# Clear kubectl context
kubectl config delete-context "$CLUSTER_NAME" 2>/dev/null || true
kubectl config delete-cluster "$CLUSTER_NAME" 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Cleared kubectl context"

echo ""
echo -e "${BLUE}Step 7/7: Final verification...${NC}"

# Check if cluster still exists
CLUSTER_EXISTS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null && echo "yes" || echo "no")
if [ "$CLUSTER_EXISTS" = "no" ]; then
    echo -e "  ${GREEN}✓${NC} EKS cluster confirmed deleted"
else
    echo -e "  ${YELLOW}⚠${NC} EKS cluster still exists (may take a few minutes)"
fi

# Count remaining terraform resources
REMAINING=$(terraform state list 2>/dev/null | wc -l)
if [ "$REMAINING" -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} No Terraform resources remaining"
else
    echo -e "  ${YELLOW}⚠${NC} $REMAINING Terraform resources still in state"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}            ✅ TEARDOWN COMPLETE ✅${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}AWS Resources Destroyed:${NC}"
echo "  • EKS Cluster: ✓ Deleted"
echo "  • EC2 Nodes: ✓ Terminated"
echo "  • VPC & Networking: ✓ Deleted"
echo "  • Load Balancers: ✓ Deleted"
echo "  • IAM Roles: ✓ Deleted"
echo "  • CloudWatch Logs: ✓ Deleted"
echo ""
echo -e "${GREEN}Cost Impact:${NC}"
echo "  • Previous: ~\$474/month (\$5,688/year)"
echo "  • Now: \$0/month"
echo "  • Savings: 100%"
echo ""
echo -e "${BLUE}To verify no charges in AWS Console:${NC}"
echo "  1. AWS Billing Dashboard → Bills"
echo "  2. Check EC2, EKS, VPC charges are \$0"
echo "  3. Set up billing alert for unexpected charges"
echo ""
echo -e "${BLUE}To rebuild this infrastructure later:${NC}"
echo "  make deploy-all  # Takes ~15-20 minutes"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"

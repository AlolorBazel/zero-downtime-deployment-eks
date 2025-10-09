#!/bin/bash

# Quick verification script to ensure everything stays clean
# Run this periodically to verify no resources are accidentally created

echo "🔍 Quick AWS & Docker Resource Check"
echo "===================================="
echo ""

# Check Docker
echo "📦 Docker:"
DOCKER_IMAGES=$(docker images -q | wc -l)
DOCKER_CONTAINERS=$(docker ps -a -q | wc -l)
echo "  Images: $DOCKER_IMAGES"
echo "  Containers: $DOCKER_CONTAINERS"
if [ "$DOCKER_IMAGES" -eq 0 ] && [ "$DOCKER_CONTAINERS" -eq 0 ]; then
    echo "  ✅ Clean"
else
    echo "  ⚠️  Resources found!"
fi
echo ""

# Check AWS
echo "☁️  AWS (us-east-1):"
EKS_COUNT=$(aws eks list-clusters --region us-east-1 --query 'clusters | length(@)' --output text 2>/dev/null || echo "0")
EC2_COUNT=$(aws ec2 describe-instances --region us-east-1 \
    --filters "Name=instance-state-name,Values=running,pending,stopping,stopped" \
    --query 'Reservations | length(@)' --output text 2>/dev/null || echo "0")
LB_COUNT=$(aws elbv2 describe-load-balancers --region us-east-1 \
    --query 'LoadBalancers | length(@)' --output text 2>/dev/null || echo "0")

echo "  EKS Clusters: $EKS_COUNT"
echo "  EC2 Instances: $EC2_COUNT"
echo "  Load Balancers: $LB_COUNT"

if [ "$EKS_COUNT" -eq 0 ] && [ "$EC2_COUNT" -eq 0 ] && [ "$LB_COUNT" -eq 0 ]; then
    echo "  ✅ Clean"
else
    echo "  ⚠️  Resources found!"
fi
echo ""

# Summary
if [ "$DOCKER_IMAGES" -eq 0 ] && [ "$DOCKER_CONTAINERS" -eq 0 ] && \
   [ "$EKS_COUNT" -eq 0 ] && [ "$EC2_COUNT" -eq 0 ] && [ "$LB_COUNT" -eq 0 ]; then
    echo "✅ Everything is clean! Monthly cost: $0.00"
else
    echo "⚠️  Some resources detected. Review above."
fi

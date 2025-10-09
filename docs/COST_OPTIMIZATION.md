# AWS Cost Optimization & Monitoring

## Current Infrastructure Cost Analysis

### Monthly Cost Breakdown (Estimated)

| Resource | Configuration | Monthly Cost (USD) |
|----------|--------------|-------------------|
| **EKS Control Plane** | 1 cluster | $73.00 |
| **EC2 Worker Nodes (General)** | 3x t3.large (ON_DEMAND) | ~$190.00 |
| **EC2 Worker Nodes (Spot)** | 2x t3.large (SPOT, 70% savings) | ~$38.00 |
| **NAT Gateways** | 3x (multi-AZ) | ~$97.00 |
| **EBS Volumes** | 5x 50GB gp3 | ~$22.00 |
| **Application Load Balancer** | 1 ALB | ~$23.00 |
| **CloudWatch Logs** | 30-day retention | ~$10.00 |
| **Data Transfer** | Moderate usage | ~$20.00 |
| **KMS Key** | 1 key | $1.00 |
| **VPC (subnets, route tables)** | Standard | $0.00 |
| **Total** | | **~$474/month** |

**Annual Cost: ~$5,688**

## Critical Cost Drivers

### 1. NAT Gateways ($97/month - 20% of total)
- **Current**: 3 NAT Gateways (one per AZ)
- **Cost**: $0.045/hour × 3 × 730 hours = $98.55/month
- **Problem**: Highest cost per resource after compute

### 2. EC2 Worker Nodes ($228/month - 48% of total)
- **Current**: 5 nodes (3 on-demand + 2 spot)
- **t3.large**: 2 vCPU, 8 GB RAM
- **Usage**: Likely underutilized for demo workloads

### 3. EKS Control Plane ($73/month - 15% of total)
- **Fixed cost** per cluster
- **No optimization** possible without destroying cluster

## Optimization Strategies

### Immediate Cost Savings (No Service Impact)

#### 1. Switch to Single NAT Gateway
**Savings: $65/month (68% reduction)**

```bash
# Current: 3 NAT Gateways
# Optimized: 1 NAT Gateway

# Trade-off: Loss of multi-AZ redundancy for NAT
# Impact: If NAT fails, private subnets lose internet (low risk for dev/staging)
```

**Implementation**: Set `single_nat_gateway = true` in Terraform

#### 2. Reduce Node Count
**Savings: $63/month (27% reduction in compute)**

```bash
# Current: 3 on-demand + 2 spot = 5 nodes
# Optimized: 2 on-demand + 1 spot = 3 nodes

# Sufficient for:
# - 3 blue-green pods
# - 5 canary pods
# - Monitoring stack
```

**Implementation**: Adjust `desired_size` in `variables.tf`

#### 3. Use Smaller Instance Types
**Savings: $76/month (33% reduction in compute)**

```bash
# Current: t3.large (2 vCPU, 8 GB)
# Optimized: t3.medium (2 vCPU, 4 GB)

# Sufficient for lightweight demo apps
```

#### 4. Reduce CloudWatch Log Retention
**Savings: $5/month**

```bash
# Current: 30 days
# Optimized: 7 days (for demo/dev)
```

**Total Immediate Savings: $209/month (44% reduction)**
**New Monthly Cost: $265**

### Aggressive Optimization (Development/Demo Only)

#### 5. Disable CloudWatch Logging
**Savings: $10/month**

Set `enable_cloudwatch_logs = false` for non-production

#### 6. Disable KMS Encryption
**Savings: $1/month**

Set `enable_kms_encryption = false` for dev environments

#### 7. Use 100% Spot Instances
**Savings: Additional $114/month (60% reduction on compute)**

```bash
# Current: Mix of on-demand + spot
# Optimized: All spot instances

# Risk: Spot interruptions (acceptable for dev/demo)
```

**Maximum Savings: $334/month (70% reduction)**
**Minimum Monthly Cost: $140**

## Cost Monitoring Setup

### 1. AWS Cost Explorer Tags

Ensure all resources have proper tags:
```hcl
tags = {
  Project     = "Zero-Downtime-Deployment"
  Environment = "production"
  ManagedBy   = "Terraform"
  CostCenter  = "engineering"
}
```

### 2. AWS Budgets

Create budget alerts:
- **Budget**: $300/month
- **Alert at**: 80% ($240), 100% ($300), 120% ($360)
- **Notification**: Email alert

### 3. CloudWatch Billing Alarms

```bash
# Alert when estimated charges exceed threshold
aws cloudwatch put-metric-alarm \
  --alarm-name eks-cost-alert \
  --alarm-description "Alert when monthly costs exceed $300" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 300 \
  --comparison-operator GreaterThanThreshold
```

## Resource Cleanup Procedures

### Daily Cleanup (Development)

Stop resources when not in use:
```bash
# Scale down node groups
make scale-down

# Or manually:
aws eks update-nodegroup-config \
  --cluster-name zdd-eks-production \
  --nodegroup-name general \
  --scaling-config minSize=0,maxSize=3,desiredSize=0
```

### Complete Teardown

**CRITICAL: This destroys ALL infrastructure**

```bash
# 1. Backup any important data
kubectl get all -A > cluster-backup.yaml

# 2. Delete Kubernetes resources first
kubectl delete namespace applications
kubectl delete namespace monitoring
kubectl delete namespace argo-rollouts

# 3. Destroy Terraform infrastructure
make destroy

# Estimated destruction time: 10-15 minutes
# Cost savings: $474/month ($16/day)
```

### Partial Teardown (Keep VPC)

```bash
# Destroy only compute resources, keep networking
terraform destroy -target=module.eks
terraform destroy -target=helm_release.argo_rollouts
terraform destroy -target=helm_release.aws_load_balancer_controller

# Savings: ~$330/month
# Remaining: VPC + NAT ($97/month for idle infrastructure)
```

## Cost Optimization Makefile Targets

See `Makefile` for these commands:
- `make cost-estimate` - Show current infrastructure costs
- `make scale-down` - Reduce node count to 0 (stop paying for compute)
- `make scale-up` - Restore normal node count
- `make destroy-confirm` - Safe infrastructure teardown with confirmation

## Production Cost Optimization

For production deployments:

### Do NOT Compromise:
- ❌ Multi-AZ NAT gateways (keep redundancy)
- ❌ On-demand instances for critical workloads
- ❌ CloudWatch logging (required for auditing)
- ❌ KMS encryption (security requirement)

### DO Optimize:
- ✅ Use Reserved Instances (up to 72% savings with 3-year commitment)
- ✅ Use Compute Savings Plans
- ✅ Implement Cluster Autoscaler or Karpenter
- ✅ Right-size instances based on actual metrics
- ✅ Use S3 for log archiving (cheaper than CloudWatch long-term)
- ✅ Implement pod resource requests/limits
- ✅ Use Fargate for burst workloads

### Production Monthly Cost (Optimized):
- Reserved Instances: $80-100/month (vs $228 on-demand)
- **Total: ~$300-350/month** with reserved capacity

## Monitoring Dashboard

Key metrics to track:
1. **Daily costs** - CloudWatch Billing
2. **Node utilization** - Kubernetes metrics
3. **Pod resource usage** - `kubectl top pods`
4. **Spot interruptions** - CloudWatch events
5. **NAT Gateway traffic** - CloudWatch metrics

## Cost Anomaly Detection

Enable AWS Cost Anomaly Detection:
- Automatically detect unusual spending
- ML-based alerts
- Free service (pay only for resources)

## Summary

| Scenario | Monthly Cost | Savings | Use Case |
|----------|-------------|---------|----------|
| **Current** | $474 | - | Full production setup |
| **Optimized** | $265 | 44% | Recommended for demos |
| **Aggressive** | $140 | 70% | Development only |
| **Destroyed** | $0 | 100% | When not in use |

**Recommendation**: Implement immediate optimizations ($265/month) or destroy when not actively using ($0/month).

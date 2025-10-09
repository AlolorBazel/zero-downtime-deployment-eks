# Quick Start# 🚀 Quick Start Guide



## PrerequisitesGet your zero-downtime deployment infrastructure running in **under 30 minutes**!



- AWS CLI configured## Prerequisites Checklist

- Terraform >= 1.6

- kubectl >= 1.28Before starting, ensure you have:

- Argo Rollouts CLI

- [ ] AWS Account with admin access

## Deploy Infrastructure- [ ] AWS CLI installed and configured

- [ ] Terraform ≥ 1.6.0 installed

```bash- [ ] kubectl ≥ 1.28.0 installed

# Configure variables- [ ] Helm ≥ 3.12.0 installed

cp terraform.tfvars.example terraform.tfvars- [ ] 30 minutes of time

# Edit terraform.tfvars with your settings- [ ] ☕ Coffee (optional but recommended)



# Deploy## Step 1: Verify Prerequisites (2 minutes)

terraform init

terraform apply```bash

```# Check all required tools

make check-tools

## Configure Access

# Or manually verify:

```bashterraform version

aws eks update-kubeconfig --name zdd-eks-dev --region us-east-1kubectl version --client

kubectl get nodes  # Should show 3 nodeshelm version

```aws --version



## Install Argo Rollouts# Verify AWS credentials

aws sts get-caller-identity

```bash```

kubectl create namespace argo-rollouts

kubectl apply -n argo-rollouts -f \Expected output:

  https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml```json

{

# Install CLI    "UserId": "AIDAI...",

curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64    "Account": "123456789012",

chmod +x kubectl-argo-rollouts-linux-amd64    "Arn": "arn:aws:iam::123456789012:user/your-user"

sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts}

``````



## Deploy Monitoring## Step 2: Clone and Configure (3 minutes)



```bash```bash

kubectl apply -f k8s/monitoring/prometheus-quick-fix.yaml# Clone the repository

kubectl get pods -n monitoring  # Wait for pods to be readygit clone https://github.com/yourusername/zero-downtime-deployment.git

```cd zero-downtime-deployment



## Deploy Applications# Create your configuration file

cp terraform.tfvars.example terraform.tfvars

```bash

kubectl create namespace applications# Edit with your preferred editor

kubectl apply -f k8s/blue-green/rollout-simple.yamlnano terraform.tfvars

kubectl apply -f k8s/canary/rollout-simple.yaml# OR

```vim terraform.tfvars

```

## Verify Deployment

**Minimum required changes in terraform.tfvars:**

```bash```hcl

# Check rolloutsproject_name = "my-zdd-project"  # Change this

kubectl argo rollouts list -n applicationsenvironment  = "dev"             # dev/staging/production

aws_region   = "us-east-1"       # Your preferred region

# Both should show "Healthy" status```

kubectl argo rollouts get rollout demo-app-blue-green -n applications

kubectl argo rollouts get rollout demo-app-canary -n applications## Step 3: Deploy Infrastructure (15 minutes)

```

### Option A: Automated Deployment (Recommended)

## Access Services

```bash

```bash# This does everything for you!

# Argo Rollouts Dashboardchmod +x scripts/deploy-infrastructure.sh

kubectl argo rollouts dashboard./scripts/deploy-infrastructure.sh

```

# Grafana

kubectl port-forward -n monitoring svc/grafana 3000:80The script will:

# http://localhost:3000 (admin / Admin123ZDD)- ✅ Validate prerequisites

- ✅ Deploy Terraform infrastructure

# Get LoadBalancer URLs- ✅ Configure kubectl

kubectl get svc -n applications- ✅ Deploy monitoring stack

```- ✅ Deploy demo applications

- ✅ Show access information

## Test Deployment

### Option B: Step-by-Step Deployment

### Blue-Green

```bash

```bash# 1. Initialize Terraform

# Update imagemake init

kubectl argo rollouts set image demo-app-blue-green \

  demo-app=<your-registry>/demo-app:v2 -n applications# 2. Review the plan

make plan

# Promote

kubectl argo rollouts promote demo-app-blue-green -n applications# 3. Apply infrastructure

```make apply

# Type 'yes' when prompted

### Canary

# 4. Configure kubectl

```bashmake kubectl-config

# Update image (auto-progresses)

kubectl argo rollouts set image demo-app-canary \# 5. Deploy monitoring

  demo-app=<your-registry>/demo-app:v2 -n applicationsmake deploy-monitoring



# Watch progression# 6. Deploy applications

kubectl argo rollouts get rollout demo-app-canary -n applications --watchmake deploy-apps

``````



## Cleanup### What's Being Created?



```bashDuring deployment, Terraform creates:

# Remove applications- 1x VPC with 9 subnets across 3 AZs

kubectl delete namespace applications- 3x NAT Gateways

- 1x EKS Cluster (Control Plane)

# Destroy infrastructure- 5x EC2 Instances (Worker Nodes)

terraform destroy- 2-3x Application Load Balancers

```- Security Groups, IAM Roles, KMS Keys

- EBS Volumes for storage

## Troubleshooting

**Estimated creation time:** 12-15 minutes

### Pods not starting

```bash## Step 4: Verify Deployment (5 minutes)

kubectl describe pod <pod-name> -n <namespace>

kubectl logs <pod-name> -n <namespace>```bash

```# Check cluster status

kubectl get nodes

### LoadBalancer not provisioning

- Check AWS VPC settings# Should show 5 nodes in Ready state:

- Verify subnet tags# NAME                         STATUS   ROLES    AGE   VERSION

- Check IAM permissions# ip-10-0-1-123.ec2.internal   Ready    <none>   5m    v1.28.x

# ip-10-0-2-234.ec2.internal   Ready    <none>   5m    v1.28.x

### Argo Rollouts issues# ...

```bash

kubectl logs -n argo-rollouts deployment/argo-rollouts# Check all pods are running

```kubectl get pods -A



For detailed documentation, see [docs/](./docs/).# Check rollouts

make rollout-status

# Should show:
# NAMESPACE      NAME                   STATUS   AGE
# applications   demo-app-blue-green    Healthy  2m
# applications   demo-app-canary        Healthy  2m
```

## Step 5: Access the Dashboard (5 minutes)

### Grafana (Monitoring Dashboard)

```bash
# Terminal 1: Port forward to Grafana
make port-forward-grafana

# Terminal 2: Get the password
make get-grafana-password
```

Open browser: http://localhost:3000
- **Username:** admin
- **Password:** (from the command above)

### Argo Rollouts Dashboard

```bash
# Port forward to Argo Rollouts
make port-forward-argo
```

Open browser: http://localhost:3100

### Prometheus

```bash
# Port forward to Prometheus
make port-forward-prometheus
```

Open browser: http://localhost:9090

## Step 6: Try a Deployment (5 minutes)

### Test Blue-Green Deployment

```bash
# Watch the rollout
kubectl argo rollouts get rollout demo-app-blue-green -n applications --watch

# In another terminal, update the image
kubectl argo rollouts set image demo-app-blue-green \
  demo-app=nginx:1.25 \
  -n applications

# The rollout will:
# 1. Deploy new version to preview
# 2. Run analysis
# 3. Wait for manual promotion

# Promote when ready
make promote-blue-green

# Or rollback if needed
kubectl argo rollouts undo demo-app-blue-green -n applications
```

### Test Canary Deployment

```bash
# Watch the canary
kubectl argo rollouts get rollout demo-app-canary -n applications --watch

# Update the image
kubectl argo rollouts set image demo-app-canary \
  demo-app=nginx:1.25 \
  -n applications

# Watch automatic progression:
# 10% -> 25% -> 50% -> 75% -> 100%
# Each step runs analysis automatically

# Manually promote to next step (if needed)
make promote-canary
```

## Common Commands Cheat Sheet

```bash
# Infrastructure
make apply          # Deploy/update infrastructure
make destroy        # Destroy all infrastructure
make outputs        # Show Terraform outputs

# Kubernetes
make pods           # List all pods
make services       # List all services
make nodes          # Show cluster nodes
make events         # Show recent events

# Rollouts
make rollout-status        # Show all rollouts
make promote-blue-green    # Promote blue-green
make promote-canary        # Promote canary
make abort-blue-green      # Abort and rollback
make abort-canary          # Abort and rollback

# Monitoring
make port-forward-grafana     # Access Grafana
make port-forward-prometheus  # Access Prometheus
make port-forward-argo        # Access Argo dashboard

# Logs
make logs-blue-green   # Tail blue-green logs
make logs-canary       # Tail canary logs

# Troubleshooting
make top-nodes        # Node resource usage
make top-pods         # Pod resource usage
make test-connections # Test all connections
```

## Quick Troubleshooting

### Issue: Terraform apply fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Ensure you have sufficient quotas
aws service-quotas list-service-quotas --service-code eks

# Check for existing resources
terraform state list
```

### Issue: Pods not starting

```bash
# Check pod status
kubectl get pods -n applications

# Describe problematic pod
kubectl describe pod <pod-name> -n applications

# Check logs
kubectl logs <pod-name> -n applications

# Check node resources
kubectl top nodes
```

### Issue: Can't access services

```bash
# Check services
kubectl get svc -A

# Check ingress
kubectl get ingress -A

# Verify ALB controller
kubectl get pods -n ingress

# Check ALB in AWS Console
aws elbv2 describe-load-balancers
```

## Next Steps

Now that your infrastructure is running:

1. **Explore the dashboards:**
   - Grafana: Monitor metrics and deployments
   - Argo Rollouts: Watch deployment strategies in action
   - Prometheus: Query raw metrics

2. **Customize the configuration:**
   - Adjust node group sizes in `terraform.tfvars`
   - Modify rollout strategies in `k8s/` files
   - Configure alerting in monitoring stack

3. **Set up CI/CD:**
   - Configure GitHub Actions workflows
   - Add your ECR repository
   - Set up webhook notifications

4. **Deploy your application:**
   - Replace demo app with your application
   - Update Dockerfile and manifests
   - Configure ingress with your domain

5. **Production hardening:**
   - Review security settings
   - Configure backup strategies
   - Set up disaster recovery
   - Implement network policies

## Cost Management

**Current infrastructure costs approximately $519/month:**
- EKS Control Plane: $73
- EC2 Instances: $229
- NAT Gateways: $97
- Load Balancers: $50
- Other: $70

**To reduce costs in dev/staging:**

```hcl
# In terraform.tfvars
single_nat_gateway = true        # Saves ~$64/month
cluster_version = "1.28"         # Use supported version

node_groups = {
  general = {
    instance_types = ["t3.medium"]  # Smaller instances
    min_size       = 1
    max_size       = 3
    desired_size   = 2
  }
}
```

**Remember to destroy when not in use:**
```bash
make destroy
```

## Getting Help

- 📖 **Full Documentation:** See [README.md](README.md)
- 📝 **Technical Guide:** See [TECHNICAL_WRITING_GUIDE.md](TECHNICAL_WRITING_GUIDE.md)
- 🐛 **Issues:** GitHub Issues
- 💬 **Community:** Join our Slack

## Success Checklist

- [ ] Infrastructure deployed successfully
- [ ] All nodes are Ready
- [ ] All pods are Running
- [ ] Monitoring dashboards accessible
- [ ] Blue-green deployment works
- [ ] Canary deployment works
- [ ] Can access applications via LoadBalancer
- [ ] Prometheus collecting metrics
- [ ] Grafana showing data

**Congratulations! 🎉 You now have a production-grade zero-downtime deployment infrastructure!**

---

**Tip:** Bookmark this guide for quick reference. Use `make help` to see all available commands.

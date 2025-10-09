# Blue-Green Deployment

Blue-green deployment configuration using Argo Rollouts.

## Configuration

- **File**: `rollout-simple.yaml`
- **Replicas**: 3
- **Strategy**: Manual promotion with preview
- **Services**: 
  - `demo-app-active` (LoadBalancer)
  - `demo-app-preview` (ClusterIP)

## Usage

```bash
# Deploy
kubectl apply -f rollout-simple.yaml

# Update image
kubectl argo rollouts set image demo-app-blue-green -n applications \
  demo-app=<image>:<tag>

# Preview new version
kubectl port-forward svc/demo-app-preview 8081:80 -n applications

# Promote to production
kubectl argo rollouts promote demo-app-blue-green -n applications

# Rollback
kubectl argo rollouts abort demo-app-blue-green -n applications
```

## Key Features

- Instant traffic cutover
- Zero downtime
- Easy rollback
- Preview environment for testing

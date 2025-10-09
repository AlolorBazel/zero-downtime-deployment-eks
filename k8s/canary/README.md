# Canary Deployment

Canary deployment configuration with progressive traffic shifting.

## Configuration

- **File**: `rollout-simple.yaml`
- **Replicas**: 5
- **Strategy**: Time-based progressive rollout
- **Traffic Steps**: 10% → 25% → 50% → 75% → 100%
- **Pause Duration**: 2 minutes per step

## Usage

```bash
# Deploy
kubectl apply -f rollout-simple.yaml

# Update image (triggers automatic progression)
kubectl argo rollouts set image demo-app-canary -n applications \
  demo-app=<image>:<tag>

# Watch progression
kubectl argo rollouts get rollout demo-app-canary -n applications --watch

# Manual promotion (skip wait)
kubectl argo rollouts promote demo-app-canary -n applications

# Abort and rollback
kubectl argo rollouts abort demo-app-canary -n applications
kubectl argo rollouts undo demo-app-canary -n applications
```

## Key Features

- Progressive traffic shifting
- Automated health validation
- Gradual risk exposure
- Abort at any step

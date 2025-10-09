# Monitoring Stack

Prometheus and Grafana for cluster and application monitoring.

## Configuration

- **File**: `prometheus-quick-fix.yaml`
- **Components**: Prometheus, Grafana, Alertmanager
- **Storage**: emptyDir (non-persistent)
- **Retention**: 2 hours

## Access

### Grafana
```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
# URL: http://localhost:3000
# Credentials: admin / Admin123ZDD
```

### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# URL: http://localhost:9090
```

### Alertmanager
```bash
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# URL: http://localhost:9093
```

## Metrics

- Kubernetes cluster metrics
- Argo Rollouts metrics
- Application metrics
- Node metrics

# 🚀 Zero-Downtime Deployments on AWS EKS

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.31-blue)](https://kubernetes.io/)
[![Terraform](https://img.shields.io/badge/Terraform-≥1.6-623CE4?logo=terraform)](https://www.terraform.io/)
[![Argo Rollouts](https://img.shields.io/badge/Argo--Rollouts-v2.38.1-purple)](https://argoproj.github.io/rollouts/)
[![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-aws)](https://aws.amazon.com/eks/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

Production-grade implementation of **Blue-Green** and **Canary** deployment strategies using **Argo Rollouts** on **Amazon EKS**.

## 📖 Overview

This project demonstrates two zero-downtime deployment patterns with comprehensive testing and monitoring:

- **��🟢 Blue-Green Deployment**: Instant traffic cutover with immediate rollback capability
- **🕊️ Canary Deployment**: Progressive traffic shifting (10% → 25% → 50% → 75% → 100%)

**Key Results:**
- ✅ **41,350 requests** tested across both strategies
- ✅ **0 failures** (100% success rate)
- ✅ **True zero-downtime** achieved
- ✅ Comprehensive monitoring with Prometheus & Grafana

## 📚 Documentation

| Document | Description | Read Time |
|----------|-------------|-----------|
| [FOCUSED_BLOG_ARTICLE.md](./FOCUSED_BLOG_ARTICLE.md) | **Featured** - Zero-downtime strategies focused guide | 15 min |
| [TECHNICAL_ARTICLE.md](./TECHNICAL_ARTICLE.md) | Complete implementation guide (42,000 words) | 45 min |
| [docs/QUICKSTART.md](./docs/QUICKSTART.md) | Quick-start deployment guide | 10 min |
| [docs/COST_OPTIMIZATION.md](./docs/COST_OPTIMIZATION.md) | Cost analysis and optimization strategies | 15 min |

## 🚀 Quick Start

> **⚠️ Cost Warning:** Running this infrastructure costs approximately **$474/month**. See [docs/COST_OPTIMIZATION.md](./docs/COST_OPTIMIZATION.md) for ways to reduce costs to $138/month.

See [TECHNICAL_ARTICLE.md](./TECHNICAL_ARTICLE.md) for complete setup instructions.

## 💰 Cost Considerations

**Infrastructure Costs (if deployed):**
- Standard configuration: ~$474/month
- Optimized configuration: ~$138/month (71% savings)

See [docs/COST_OPTIMIZATION.md](./docs/COST_OPTIMIZATION.md) for detailed breakdown and optimization strategies.

## 🛠️ Infrastructure Management

### Deploy Infrastructure
```bash
./scripts/deploy-infrastructure.sh
```

### Destroy Infrastructure
```bash
./scripts/destroy-all.sh
```

### Verify Cleanup
```bash
./scripts/verify-cleanup.sh
```

---

**Built with:** Kubernetes • EKS • Argo Rollouts • Terraform • Prometheus  
**License:** MIT  
**Last Updated:** October 9, 2025

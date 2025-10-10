# 🚀 Quick Start Guide

## Live API: http://34.143.235.74

### Test ngay:

```bash
# Health check
curl http://34.143.235.74/health

# Get products
curl http://34.143.235.74/products

# Get categories
curl http://34.143.235.74/categories

# Search laptop
curl "http://34.143.235.74/products?search=laptop"
```

## Monitoring:

```bash
# View status
kubectl get pods -n ecommerce
kubectl get services -n ecommerce

# View logs
kubectl logs -f deployment/products-service-deployment -n ecommerce
```

## Scaling:

```bash
# Scale up
kubectl scale deployment products-service-deployment -n ecommerce --replicas=5

# Scale down
kubectl scale deployment products-service-deployment -n ecommerce --replicas=2
```

## Cleanup (when done):

```bash
./scripts/cleanup.sh
```

## Full Documentation:

- [DEPLOYMENT_SUCCESS.md](DEPLOYMENT_SUCCESS.md) - Complete guide
- [docs/architecture.md](docs/architecture.md) - Architecture details
- [infrastructure/k8s/README.md](infrastructure/k8s/README.md) - K8s details

---

**Status:** 🟢 Live on GCP
**Cluster:** my-ecommerce-cluster (asia-southeast1)
**Pods:** 2/2 Running
**External IP:** 34.143.235.74

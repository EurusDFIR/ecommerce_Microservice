# 🚀 Quick Reference - E-commerce Microservices

**Last Updated:** October 11, 2025

---

## 📋 Essential Commands

### GKE Cluster Access

```bash
# Get credentials
gcloud container clusters get-credentials my-ecommerce-cluster \
  --region=asia-southeast1 --project=ecommerce-micro-0037

# Check status
kubectl get pods -n ecommerce
kubectl get services -n ecommerce
kubectl get deployments -n ecommerce
```

### View Logs

```bash
# Users Service
kubectl logs -f deployment/users-service-postgres-deployment -n ecommerce

# Products Service
kubectl logs -f deployment/products-service-postgres-deployment -n ecommerce

# Orders Service
kubectl logs -f deployment/orders-service-firestore-deployment -n ecommerce

# Cloud SQL Proxy
kubectl logs -f deployment/users-service-postgres-deployment -c cloud-sql-proxy -n ecommerce
```

### Port Forwarding (Local Testing)

```bash
# Users Service
kubectl port-forward svc/users-service 8001:80 -n ecommerce

# Products Service
kubectl port-forward svc/products-service 8002:80 -n ecommerce

# Orders Service
kubectl port-forward svc/orders-service 8003:80 -n ecommerce
```

### Database Access

```bash
# Cloud SQL PostgreSQL
gcloud sql connect ecommerce-postgres --user=postgres --project=ecommerce-micro-0037
# Password: PostgresAdmin2024!

# Check databases
\l
\c users_db
\dt
```

### E2E Testing

```bash
# Run test script
cd /r/_Projects/Eurus_Workspace/e_commerce_microservice
./scripts/test-e2e.sh

# Expected: 7/7 tests passing ✅
```

---

## 🌐 API Endpoints

**Base URL:** `http://34.143.235.74`

### Users Service

```bash
# Health Check
curl http://34.143.235.74/health

# Register
curl -X POST http://34.143.235.74/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123","full_name":"Test User","role":"customer"}'

# Login
curl -X POST http://34.143.235.74/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"customer@example.com","password":"customer123"}'
```

### Products Service

```bash
# Get all products
curl http://34.143.235.74/products

# Get by category
curl http://34.143.235.74/products?category=Electronics

# Search
curl http://34.143.235.74/products/search?q=laptop

# Get categories
curl http://34.143.235.74/categories
```

### Orders Service (Requires Auth)

```bash
# Set token
TOKEN="your-jwt-token-here"

# Add to cart
curl -X POST http://34.143.235.74/orders/cart \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"productId":1,"quantity":2}'

# View cart
curl http://34.143.235.74/orders/cart \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🗄️ Database Schemas

### users_db (PostgreSQL)

- `users` - User accounts
- `user_addresses` - Shipping addresses
- `user_sessions` - Active JWT sessions
- `user_audit_log` - Activity tracking

### products_db (PostgreSQL)

- `categories` - Product categories
- `products` - Product catalog
- `product_variants` - Product options
- `product_reviews` - User reviews
- `stock_movements` - Inventory tracking

### Firestore (NoSQL)

- `carts` - Shopping carts
- `orders` - Order history

---

## 🔐 Credentials

### Cloud SQL

- **Instance:** `ecommerce-postgres`
- **Host:** `35.247.191.172`
- **User:** `postgres`
- **Password:** `PostgresAdmin2024!`
- **Databases:** `users_db`, `products_db`

### GCP Project

- **Project ID:** `ecommerce-micro-0037`
- **Project Number:** `726566173093`
- **Region:** `asia-southeast1`

### Service Accounts

- **App SA:** `ecommerce-services-sa@ecommerce-micro-0037.iam.gserviceaccount.com`
- **CI/CD SA:** `github-actions-sa@ecommerce-micro-0037.iam.gserviceaccount.com`

### Kubernetes

- **Cluster:** `my-ecommerce-cluster`
- **Namespace:** `ecommerce`
- **Service Account:** `ecommerce-ksa`

---

## 📦 Docker Images

**Registry:** `asia-southeast1-docker.pkg.dev/ecommerce-micro-0037/ecommerce-images`

### Current Versions

```
users-service:v2.4-postgres
products-service:v2-postgres
orders-service:v2.2-firestore
```

### Build Commands

```bash
# Users Service
cd services/users-service
docker build -t asia-southeast1-docker.pkg.dev/ecommerce-micro-0037/ecommerce-images/users-service:v2.5-postgres -f Dockerfile.postgres .
docker push asia-southeast1-docker.pkg.dev/ecommerce-micro-0037/ecommerce-images/users-service:v2.5-postgres

# Products Service
cd services/products-service
docker build -t asia-southeast1-docker.pkg.dev/ecommerce-micro-0037/ecommerce-images/products-service:v2.1-postgres -f Dockerfile.postgres .
docker push asia-southeast1-docker.pkg.dev/ecommerce-micro-0037/ecommerce-images/products-service:v2.1-postgres

# Orders Service
cd services/orders-service
docker build -t asia-southeast1-docker.pkg.dev/ecommerce-micro-0037/ecommerce-images/orders-service:v2.3-firestore -f Dockerfile.firestore .
docker push asia-southeast1-docker.pkg.dev/ecommerce-micro-0037/ecommerce-images/orders-service:v2.3-firestore
```

---

## 🚀 Deployment

### Update Deployment

```bash
# Update image
kubectl set image deployment/users-service-postgres-deployment \
  users-service=asia-southeast1-docker.pkg.dev/ecommerce-micro-0037/ecommerce-images/users-service:NEW_VERSION \
  -n ecommerce

# Watch rollout
kubectl rollout status deployment/users-service-postgres-deployment -n ecommerce

# Rollback if needed
kubectl rollout undo deployment/users-service-postgres-deployment -n ecommerce
```

### Restart Services

```bash
# Restart all
kubectl rollout restart deployment/users-service-postgres-deployment -n ecommerce
kubectl rollout restart deployment/products-service-postgres-deployment -n ecommerce
kubectl rollout restart deployment/orders-service-firestore-deployment -n ecommerce
```

### Scale Services

```bash
# Scale up
kubectl scale deployment/users-service-postgres-deployment --replicas=3 -n ecommerce

# Scale down
kubectl scale deployment/users-service-postgres-deployment --replicas=1 -n ecommerce
```

---

## 🧪 Testing

### Postman

1. Import collection: `postman/E-commerce_Microservices_API_Collection.json`
2. Run folder: "4. E2E Test Flow"
3. Expected: 6/6 steps passing ✅

### Newman CLI

```bash
npm install -g newman
newman run postman/E-commerce_Microservices_API_Collection.json
```

### E2E Script

```bash
./scripts/test-e2e.sh
# Expected: 7/7 tests passing ✅
```

---

## 🔄 CI/CD Workflows

### GitHub Actions

- **Location:** `.github/workflows/`
- **Files:**
  - `ci-pull-request.yml` - PR validation
  - `cd-deploy.yml` - Auto deployment
  - `database-migrations.yml` - DB migrations
  - `hotfix-deployment.yml` - Emergency fixes

### Trigger Deployment

```bash
# Push to main branch
git push origin main

# Or manual trigger
# Go to: Actions > CD - Deploy to GKE > Run workflow
```

---

## 📊 Monitoring

### Check Pod Status

```bash
kubectl get pods -n ecommerce -o wide
kubectl describe pod POD_NAME -n ecommerce
```

### View Events

```bash
kubectl get events -n ecommerce --sort-by='.lastTimestamp'
```

### Resource Usage

```bash
kubectl top pods -n ecommerce
kubectl top nodes
```

---

## 🐛 Troubleshooting

### Pod Not Running

```bash
# Check pod status
kubectl get pods -n ecommerce

# View logs
kubectl logs POD_NAME -n ecommerce

# Describe pod
kubectl describe pod POD_NAME -n ecommerce

# Check events
kubectl get events -n ecommerce
```

### Database Connection Issues

```bash
# Test Cloud SQL Proxy
kubectl exec -it POD_NAME -c cloud-sql-proxy -n ecommerce -- sh

# Check secrets
kubectl get secrets -n ecommerce
kubectl describe secret cloudsql-db-credentials -n ecommerce
```

### Service Not Accessible

```bash
# Check services
kubectl get svc -n ecommerce

# Check endpoints
kubectl get endpoints -n ecommerce

# Port forward and test locally
kubectl port-forward svc/users-service 8001:80 -n ecommerce
curl http://localhost:8001/health
```

---

## 📁 Important Files

### Configuration

- `.github/workflows/*.yml` - CI/CD workflows
- `infrastructure/k8s/*.yaml` - Kubernetes manifests
- `database/migrations/*.sql` - Database schemas
- `.gitignore` - Security (150+ rules)

### Documentation

- `README.md` - Project overview
- `docs/ARCHITECTURE_DIAGRAM.md` - System architecture
- `docs/CI_CD_PIPELINE.md` - CI/CD guide
- `docs/GITHUB_ACTIONS_SETUP.md` - Setup instructions
- `postman/README.md` - API testing guide

### Scripts

- `scripts/test-e2e.sh` - End-to-end testing
- `scripts/setup-databases.sh` - Database setup

---

## 🔗 Quick Links

- **GitHub Repo:** https://github.com/EurusDFIR/ecommerce_Microservice
- **GCP Console:** https://console.cloud.google.com/home/dashboard?project=ecommerce-micro-0037
- **GKE Cluster:** https://console.cloud.google.com/kubernetes/clusters/details/asia-southeast1/my-ecommerce-cluster?project=ecommerce-micro-0037
- **Cloud SQL:** https://console.cloud.google.com/sql/instances?project=ecommerce-micro-0037
- **Firestore:** https://console.cloud.google.com/firestore/databases?project=ecommerce-micro-0037

---

## 📞 Support

### Get Help

1. Check logs: `kubectl logs -f POD_NAME -n ecommerce`
2. Check events: `kubectl get events -n ecommerce`
3. Run E2E tests: `./scripts/test-e2e.sh`
4. Review documentation in `docs/` folder

### Common Issues

- **401 Unauthorized:** Token expired, login again
- **Connection refused:** Service not running, check pods
- **Image pull error:** Check image name/tag
- **Database error:** Check Cloud SQL Proxy logs

---

**Version:** 2.0  
**Status:** ✅ Production Ready  
**Last Tested:** October 11, 2025

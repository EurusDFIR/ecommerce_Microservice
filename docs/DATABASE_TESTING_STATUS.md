# Database Integration Testing Status

**Date**: October 11, 2025  
**Priority**: #1 - Database Integration (Cloud SQL & Firestore)  
**Status**: 🟡 In Progress - Bug Fixes Complete, Testing in Final Phase

---

## ✅ Completed

### Infrastructure

- ✅ Cloud SQL PostgreSQL instance created (`ecommerce-postgres`)
- ✅ Firestore database created (Native mode, `asia-southeast1`)
- ✅ IAM service accounts configured with proper roles
- ✅ Workload Identity binding established
- ✅ Kubernetes secrets created (database credentials, JWT)

### Code & Deployments

- ✅ Users service updated with PostgreSQL (`app-postgres.js`)
- ✅ Products service updated with PostgreSQL (`app-postgres.js`)
- ✅ Orders service updated with Firestore (`app-firestore.js`)
- ✅ All services deployed to GKE with database clients
- ✅ Database migrations completed (9 tables total)
- ✅ Sample data inserted (2 users, 5 products)

### Bug Fixes

- ✅ Fixed JWT token field inconsistency (`id` vs `userId`)
- ✅ Fixed JWT verify endpoint response format
- ✅ Fixed inter-service token verification logic
- ✅ Removed old v1 deployments to prevent routing conflicts
- ✅ Updated service target ports (8081, 8080, 8082)

### Testing Results

- ✅ User registration works (PostgreSQL persistence)
- ✅ User login works (JWT generation)
- ✅ Product listing works (PostgreSQL queries)
- ✅ Health checks pass for all services

---

## 🟡 In Progress

### Current Issue

**Cart Functionality Testing**

The `POST /cart/items` endpoint is ready but requires stable port-forwarding for final E2E testing.

**Last Observed Error**: Port-forward connections unstable during testing

**Root Cause Analysis**:

1. ✅ JWT token format mismatch - **FIXED** (v2.2-postgres)
2. ✅ Inter-service verify endpoint - **FIXED** (returns `{success, data}`)
3. ✅ Old v1 deployments causing routing issues - **FIXED** (deleted)
4. ⏳ Port-forward stability for local testing

---

## 🔧 Bug Fixes Applied

### 1. JWT Token Field Mapping

**File**: `services/users-service/app-postgres.js`

**Problem**: Token payload used `userId` but code generated with `id`

**Fix**:

```javascript
// Changed from:
{
  userId: user.id, email, role;
}

// To:
{
  id: user.id, email, role;
} // Line 60
```

### 2. Verify Endpoint Response Format

**File**: `services/users-service/app-postgres.js`

**Problem**: Inconsistent API response format

**Fix**:

```javascript
// Changed from:
{ valid: true, user: {...} }

// To:
{ success: true, data: { userId: decoded.id, email, role } }  // Line 310
```

### 3. Orders Service Token Verification

**File**: `services/orders-service/app-firestore.js`

**Problem**: Expected `response.data.valid` but got `response.data.success`

**Fix**:

```javascript
// Changed from:
return response.data.valid ? response.data.user : null;

// To:
return response.data.success ? response.data.data : null; // Line 52
```

### 4. Deployment Cleanup

**Actions**:

```bash
kubectl delete deployment users-service-deployment -n ecommerce
kubectl delete deployment products-service-deployment -n ecommerce
kubectl delete deployment orders-service-deployment -n ecommerce
```

### 5. Service Port Updates

**Actions**:

```bash
kubectl patch svc users-service -n ecommerce --type='json' \
  -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value":8081}]'

kubectl patch svc products-service -n ecommerce --type='json' \
  -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value":8080}]'

kubectl patch svc orders-service -n ecommerce --type='json' \
  -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value":8082}]'
```

---

## 📋 Next Steps

### Immediate (Complete E2E Testing)

#### Option 1: Direct Pod Testing (Recommended)

Test directly inside Kubernetes without port-forwarding:

```bash
# 1. Get a test token
POD=$(kubectl get pod -l app=users-service,version=v2-postgres -n ecommerce -o jsonpath='{.items[0].metadata.name}')

kubectl exec $POD -n ecommerce -- node -e "
const http = require('http');
const postData = JSON.stringify({email:'buyer@test.com',password:'test123456'});
const options = {hostname:'users-service',port:80,path:'/auth/login',method:'POST',headers:{'Content-Type':'application/json','Content-Length':postData.length}};
const req = http.request(options, res => {res.on('data', d => console.log(d.toString()));});
req.write(postData);
req.end();
"

# 2. Extract token from response and test cart
kubectl exec $POD -n ecommerce -- node -e "
const TOKEN = 'paste_token_here';
const http = require('http');
const postData = JSON.stringify({productId:1,quantity:2});
const options = {hostname:'orders-service',port:80,path:'/cart/items',method:'POST',headers:{'Authorization':'Bearer '+TOKEN,'Content-Type':'application/json','Content-Length':postData.length}};
const req = http.request(options, res => {res.on('data', d => console.log(d.toString()));});
req.write(postData);
req.end();
"
```

#### Option 2: Ingress Setup (Production-ready)

Deploy Ingress Controller for stable external access:

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Create Ingress resource
kubectl apply -f infrastructure/k8s/ingress.yaml
```

#### Option 3: LoadBalancer Services

Expose services via LoadBalancer (temporary for testing):

```bash
kubectl patch svc users-service -n ecommerce -p '{"spec":{"type":"LoadBalancer"}}'
kubectl patch svc products-service -n ecommerce -p '{"spec":{"type":"LoadBalancer"}}'
kubectl patch svc orders-service -n ecommerce -p '{"spec":{"type":"LoadBalancer"}}'

# Get external IPs
kubectl get svc -n ecommerce
```

### Complete Workflow Test

Once stable connectivity is established:

```bash
# 1. Register/Login
curl -X POST http://<SERVICE_URL>/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"buyer@test.com","password":"test123456"}'

# Save token from response
TOKEN="<token_from_response>"

# 2. Browse Products
curl http://<SERVICE_URL>/products

# 3. Add to Cart
curl -X POST http://<SERVICE_URL>/cart/items \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"productId":1,"quantity":2}'

# 4. View Cart
curl http://<SERVICE_URL>/cart \
  -H "Authorization: Bearer $TOKEN"

# 5. Create Order
curl -X POST http://<SERVICE_URL>/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"shippingAddress":"123 Test St"}'
```

### Verify Data Persistence

#### PostgreSQL (Users & Products)

```bash
# Create migration pod
kubectl run psql-client --rm -it --image=postgres:15 -n ecommerce -- bash

# Inside pod:
export PGPASSWORD='your_secure_password_123'
psql -h <CLOUD_SQL_IP> -U users_service_user -d users_db

# Check users
SELECT id, email, role, created_at FROM users ORDER BY id DESC LIMIT 5;

# Check products
\c products_db
SELECT id, name, price, stock_quantity FROM products;
```

#### Firestore (Carts & Orders)

```bash
# Via gcloud CLI
gcloud firestore databases list
gcloud firestore collections list --database='(default)'

# Check cart documents
gcloud firestore documents list --database='(default)' --collection-id=carts

# Check order documents
gcloud firestore documents list --database='(default)' --collection-id=orders
```

---

## 📊 Current Deployment Status

### Pods Running

```
users-service-postgres (v2.2-postgres): 2/2 replicas
products-service-postgres (v2-postgres): 2/2 replicas
orders-service-firestore (v2.1-firestore): 2/2 replicas
```

### Services

```
users-service:    ClusterIP, port 80 → 8081 (PostgreSQL)
products-service: ClusterIP, port 80 → 8080 (PostgreSQL)
orders-service:   ClusterIP, port 80 → 8082 (Firestore)
```

### Database Connections

- Users Service → Cloud SQL (users_db) ✅
- Products Service → Cloud SQL (products_db) ✅
- Orders Service → Firestore (carts, orders collections) ✅

---

## 🎯 Priority #2 & #3 (Next Phase)

### Priority #2: CI/CD Pipeline

- GitHub Actions workflow for automated builds
- Automated testing before deployment
- Docker image scanning
- Automated migrations

### Priority #3: API Gateway / Ingress

- NGINX Ingress Controller
- Unified external endpoint
- TLS/SSL certificates
- Rate limiting & authentication

---

## 📝 Notes

### Image Versions

- `users-service:v2.2-postgres` - Latest with JWT fixes
- `products-service:v2-postgres` - PostgreSQL integration
- `orders-service:v2.1-firestore` - Firestore with fixed token verification

### JWT Secret

Stored in Kubernetes secret: `users-service-secrets/jwt_secret`

### Database Credentials

Stored in Kubernetes secret: `cloudsql-db-credentials`

### Service Account

- GCP: `ecommerce-services-sa@ecommerce-micro-0037.iam.gserviceaccount.com`
- K8s: `ecommerce-ksa` (with Workload Identity binding)

---

## 🐛 Known Issues

1. **Port-forward instability**: Use direct pod exec or Ingress for stable testing
2. **Token variable in bash**: Use inline curl commands or save to file
3. **Response truncation**: Full JSON responses may be cut in terminal output

---

## ✅ Success Criteria

- [x] All services deploy successfully
- [x] Database connections established
- [x] Migrations complete with sample data
- [x] JWT authentication works
- [x] Inter-service communication functional
- [ ] **Complete E2E workflow test** (cart → order)
- [ ] Data persists across pod restarts
- [ ] Performance acceptable (<500ms per request)

---

**Status**: Ready for final E2E testing using recommended direct pod testing or Ingress setup.

# 🗄️ DATABASE INTEGRATION GUIDE

## Overview

This guide documents the integration of real databases (Cloud SQL PostgreSQL and Firestore) into the E-commerce Microservices system.

---

## 🏗️ Database Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Application Layer                       │
├──────────────┬─────────────────┬──────────────────────┤
│ Users Service│ Products Service│  Orders Service      │
│              │                 │                      │
│   Node.js    │    Node.js      │    Node.js          │
│   pg client  │    pg client    │    Firestore SDK    │
└──────┬───────┴────────┬────────┴───────────┬──────────┘
       │                 │                    │
       │                 │                    │
┌──────▼─────────────────▼────────┐   ┌──────▼───────┐
│   Cloud SQL Proxy Sidecar       │   │  Firestore   │
│   (127.0.0.1:5432)             │   │  (Native)    │
└──────┬──────────────────────────┘   └──────────────┘
       │
       │
┌──────▼──────────────────────────┐
│   Cloud SQL PostgreSQL 15       │
│   ┌──────────┐  ┌────────────┐ │
│   │users_db  │  │products_db │ │
│   └──────────┘  └────────────┘ │
└─────────────────────────────────┘
```

---

## 📊 Database Details

### **1. Cloud SQL PostgreSQL**

**Instance Configuration:**

- **Instance Name:** `ecommerce-postgres`
- **Database Version:** PostgreSQL 15
- **Tier:** `db-f1-micro` (upgradeable)
- **Region:** `asia-southeast1`
- **Storage:** 10GB SSD (auto-increase enabled)
- **Backups:** Daily at 02:00, 7-day retention
- **Maintenance Window:** Sunday 03:00-04:00

**Databases:**

- **users_db** - User accounts, authentication, sessions
- **products_db** - Product catalog, categories, inventory

**Connection:**

```
Connection Name: ecommerce-micro-0037:asia-southeast1:ecommerce-postgres
Private IP: Enabled
Cloud SQL Proxy: Required for secure connection
```

### **2. Firestore**

**Configuration:**

- **Mode:** Native mode
- **Location:** `asia-southeast1`
- **Project ID:** `ecommerce-micro-0037`

**Collections:**

- **carts** - Shopping carts (document per user)
- **orders** - Order records with items
- **order_items** - Subcollection under orders (if needed)

---

## 🔧 Database Schemas

### **Users Database (users_db)**

```sql
-- Main Tables:
users                  -- User accounts
user_addresses         -- Shipping/billing addresses
user_sessions          -- JWT token tracking
user_audit_log         -- Activity audit trail

-- Key Features:
- Email uniqueness enforcement
- Password hashing (bcrypt)
- Role-based access (customer/admin)
- Session management with expiration
- Audit logging for compliance
```

**Schema Highlights:**

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(50) DEFAULT 'customer',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);
```

### **Products Database (products_db)**

```sql
-- Main Tables:
categories             -- Product categories (hierarchical)
products               -- Product catalog
product_variants       -- Size/color variations
product_reviews        -- Customer reviews
stock_movements        -- Inventory tracking

-- Key Features:
- Full-text search on product names
- Category hierarchy support
- Stock tracking with triggers
- Price history
- Tag-based search
```

**Schema Highlights:**

```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    sku VARCHAR(100) UNIQUE,
    category_id INTEGER REFERENCES categories(id),
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    tags TEXT[],
    metadata JSONB,
    is_active BOOLEAN DEFAULT true
);
```

### **Firestore Collections**

**Carts Collection:**

```json
{
  "userId": 123,
  "items": [
    {
      "productId": 1,
      "quantity": 2,
      "price": 1899.99,
      "addedAt": "2024-10-11T10:30:00Z"
    }
  ],
  "createdAt": "2024-10-11T10:30:00Z",
  "updatedAt": "2024-10-11T10:35:00Z"
}
```

**Orders Collection:**

```json
{
  "userId": 123,
  "items": [
    {
      "productId": 1,
      "productName": "Gaming Laptop",
      "quantity": 1,
      "price": 1899.99,
      "subtotal": 1899.99
    }
  ],
  "totalAmount": 1899.99,
  "shippingAddress": {
    "street": "123 Main St",
    "city": "Hanoi",
    "country": "Vietnam"
  },
  "paymentMethod": "cod",
  "status": "pending",
  "createdAt": "2024-10-11T10:40:00Z"
}
```

---

## 🚀 Setup Instructions

### **Step 1: Run Database Setup Script**

```bash
# Creates Cloud SQL and Firestore instances
chmod +x ./scripts/setup-databases.sh
./scripts/setup-databases.sh
```

This will:

- ✅ Create Cloud SQL PostgreSQL instance (5-10 minutes)
- ✅ Create users_db and products_db databases
- ✅ Create database users with permissions
- ✅ Enable Firestore API
- ✅ Create Firestore database
- ✅ Setup service accounts and IAM roles
- ✅ Create Kubernetes secrets

### **Step 2: Run Database Migrations**

```bash
# Apply SQL schemas to databases
chmod +x ./scripts/run-migrations.sh
./scripts/run-migrations.sh
```

This will:

- ✅ Start Cloud SQL Proxy
- ✅ Run schema migration for users_db
- ✅ Run schema migration for products_db
- ✅ Insert sample data

### **Step 3: Deploy Services**

```bash
# Deploy services with database connections
chmod +x ./scripts/deploy-with-databases.sh
./scripts/deploy-with-databases.sh
```

This will:

- ✅ Build Docker images with database clients
- ✅ Push images to Artifact Registry
- ✅ Deploy with Cloud SQL Proxy sidecars
- ✅ Configure environment variables
- ✅ Apply Kubernetes manifests

---

## 🔐 Security Configuration

### **1. Cloud SQL Proxy**

**Why?**

- Encrypted connection to Cloud SQL
- No need to manage SSL certificates
- Works with private IPs
- Automatic IAM authentication

**Implementation:**

```yaml
# Sidecar container in deployment
- name: cloud-sql-proxy
  image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0
  args:
    - "--structured-logs"
    - "--port=5432"
    - "ecommerce-micro-0037:asia-southeast1:ecommerce-postgres"
```

**Application Connection:**

```javascript
const pool = new Pool({
  host: "127.0.0.1", // Cloud SQL Proxy localhost
  port: 5432,
  database: "users_db",
  user: "users_service_user",
  password: process.env.DB_PASSWORD,
});
```

### **2. Secrets Management**

**Kubernetes Secrets:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudsql-db-credentials
stringData:
  connection_name: "ecommerce-micro-0037:asia-southeast1:ecommerce-postgres"
  users_db_password: "UsersService2024!"
  products_db_password: "ProductsService2024!"
```

**Best Practice:**

- ✅ Never commit credentials to Git
- ✅ Use Kubernetes Secrets for sensitive data
- ✅ Consider Google Secret Manager for production
- ✅ Rotate passwords regularly

### **3. IAM & Service Accounts**

**Service Account:**

- Email: `ecommerce-services-sa@ecommerce-micro-0037.iam.gserviceaccount.com`
- Roles:
  - `roles/cloudsql.client` - Access Cloud SQL
  - `roles/datastore.user` - Access Firestore

**Workload Identity:**

```bash
# Bind GCP SA to K8s SA
kubectl annotate serviceaccount ecommerce-ksa \
  iam.gke.io/gcp-service-account=ecommerce-services-sa@ecommerce-micro-0037.iam.gserviceaccount.com
```

---

## 📝 Code Updates

### **Users Service Changes**

**Before (In-Memory):**

```javascript
const users = [
    { id: 1, email: 'user@example.com', ... }
];
```

**After (PostgreSQL):**

```javascript
const { Pool } = require('pg');
const pool = new Pool({ ... });

// Query database
const result = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [email]
);
```

### **Products Service Changes**

**Before (In-Memory):**

```javascript
const products = [
    { id: 1, name: 'Laptop', ... }
];
```

**After (PostgreSQL):**

```javascript
const result = await pool.query(
  `SELECT p.*, c.name as category_name
     FROM products p
     LEFT JOIN categories c ON p.category_id = c.id
     WHERE p.is_active = true`
);
```

### **Orders Service Changes**

**Before (In-Memory):**

```javascript
const orders = {};
```

**After (Firestore):**

```javascript
const { Firestore } = require("@google-cloud/firestore");
const firestore = new Firestore({ projectId: "ecommerce-micro-0037" });

// Create order
await firestore.collection("orders").add(orderData);

// Query orders
const snapshot = await firestore
  .collection("orders")
  .where("userId", "==", userId)
  .get();
```

---

## 🧪 Testing Database Integration

### **1. Test Cloud SQL Connection**

```bash
# Port-forward to test locally
kubectl port-forward deployment/users-service-postgres-deployment 8081:8081 -n ecommerce

# Test health endpoint
curl http://localhost:8081/health

# Expected response:
{
  "status": "healthy",
  "database": "connected",
  "service": "users-service"
}
```

### **2. Test User Registration (PostgreSQL)**

```bash
curl -X POST http://localhost:8081/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "securepass123",
    "firstName": "Test",
    "lastName": "User"
  }'
```

### **3. Test Firestore Integration**

```bash
# Create cart item
curl -X POST http://localhost:8082/cart/items \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "productId": 1,
    "quantity": 2
  }'

# Verify in Firestore Console
# https://console.cloud.google.com/firestore/data
```

---

## 📈 Performance Optimization

### **1. Connection Pooling**

```javascript
const pool = new Pool({
  max: 20, // Maximum connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### **2. Database Indexing**

```sql
-- Already created in migration
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_products_slug ON products(slug);
CREATE INDEX idx_products_name_search ON products USING gin(to_tsvector('english', name));
```

### **3. Query Optimization**

- Use parameterized queries (prevent SQL injection)
- Leverage PostgreSQL full-text search
- Use JOINs instead of multiple queries
- Implement pagination for large result sets

### **4. Firestore Best Practices**

- Denormalize data for read optimization
- Use composite indexes for complex queries
- Implement caching for frequently accessed data
- Batch writes when possible

---

## 💰 Cost Estimation

### **Monthly Costs:**

| Resource                | Configuration          | Estimated Cost      |
| ----------------------- | ---------------------- | ------------------- |
| Cloud SQL (db-f1-micro) | 0.6GB RAM, 3GB storage | ~$15-20             |
| Cloud SQL Storage       | 10GB SSD               | ~$2                 |
| Cloud SQL Backups       | 7 days retention       | ~$1                 |
| Firestore               | Read/Write operations  | ~$0-5 (low traffic) |
| **Total**               |                        | **~$18-28/month**   |

### **Cost Optimization:**

- ✅ Use db-f1-micro for development
- ✅ Scale up only when needed
- ✅ Enable storage auto-increase (avoid over-provisioning)
- ✅ Use committed use discounts for production
- ✅ Monitor Firestore operation costs

---

## 🔍 Monitoring & Troubleshooting

### **Check Cloud SQL Status**

```bash
gcloud sql instances describe ecommerce-postgres

# Check connections
gcloud sql operations list --instance=ecommerce-postgres
```

### **Check Firestore Status**

```bash
# View Firestore data
# https://console.cloud.google.com/firestore/data

# Check IAM permissions
gcloud projects get-iam-policy ecommerce-micro-0037
```

### **Debug Cloud SQL Proxy**

```bash
# Check proxy logs
kubectl logs deployment/users-service-postgres-deployment \
  -c cloud-sql-proxy -n ecommerce

# Common issues:
# - IAM permissions not granted
# - Connection name incorrect
# - Service account not bound
```

### **Database Logs**

```bash
# Cloud SQL logs
gcloud sql operations list --instance=ecommerce-postgres --limit=10

# Application logs
kubectl logs -f deployment/users-service-postgres-deployment \
  -c users-service -n ecommerce
```

---

## 🎯 Migration Checklist

- [x] Cloud SQL instance created
- [x] Firestore database enabled
- [x] Database schemas applied
- [x] Sample data inserted
- [x] Service accounts configured
- [x] Kubernetes secrets created
- [x] Application code updated
- [x] Docker images built
- [x] Services deployed
- [ ] End-to-end testing completed
- [ ] Performance testing done
- [ ] Backup/restore tested
- [ ] Monitoring configured

---

## 📚 Additional Resources

- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Firestore Documentation](https://cloud.google.com/firestore/docs)
- [Cloud SQL Proxy Guide](https://cloud.google.com/sql/docs/postgres/connect-kubernetes-engine)
- [Node.js pg Library](https://node-postgres.com/)
- [Firestore Node.js SDK](https://googleapis.dev/nodejs/firestore/latest/)

---

**Status:** ✅ Database integration ready for deployment
**Last Updated:** October 11, 2025
**Version:** 2.0.0

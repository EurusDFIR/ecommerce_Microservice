# Kiến trúc Microservices E-Commerce

## Tổng quan kiến trúc

Hệ thống E-commerce được thiết kế theo mô hình Microservices với các nguyên tắc:

- **Loosely Coupled**: Các service độc lập với nhau
- **High Cohesion**: Mỗi service chuyên trách một domain cụ thể
- **Scalable**: Có thể scale từng service riêng biệt
- **Fault Tolerant**: Lỗi ở một service không ảnh hưởng toàn hệ thống

## Các Microservices

### 1. Users Service

**Chức năng**: Quản lý người dùng và xác thực

- **Endpoints**:
  - `POST /users/register` - Đăng ký người dùng mới
  - `POST /users/login` - Đăng nhập
  - `GET /users/profile` - Lấy thông tin profile
  - `PUT /users/profile` - Cập nhật profile
  - `POST /users/logout` - Đăng xuất
- **Database**: Cloud SQL (PostgreSQL)
- **Auth**: JWT tokens
- **Port**: 8081

### 2. Products Service

**Chức năng**: Quản lý danh mục và sản phẩm

- **Endpoints**:
  - `GET /products` - Danh sách sản phẩm (có pagination, filter)
  - `GET /products/:id` - Chi tiết sản phẩm
  - `POST /products` - Tạo sản phẩm mới (admin)
  - `PUT /products/:id` - Cập nhật sản phẩm (admin)
  - `DELETE /products/:id` - Xóa sản phẩm (admin)
  - `GET /categories` - Danh sách danh mục
- **Database**: Cloud SQL (PostgreSQL)
- **Port**: 8082

### 3. Orders Service

**Chức năng**: Xử lý giỏ hàng và đơn hàng

- **Endpoints**:
  - `GET /cart` - Lấy giỏ hàng hiện tại
  - `POST /cart/items` - Thêm sản phẩm vào giỏ
  - `PUT /cart/items/:id` - Cập nhật số lượng
  - `DELETE /cart/items/:id` - Xóa khỏi giỏ
  - `POST /orders` - Tạo đơn hàng từ giỏ hàng
  - `GET /orders` - Lịch sử đơn hàng
  - `GET /orders/:id` - Chi tiết đơn hàng
- **Database**: Firestore (NoSQL)
- **Port**: 8083

### 4. Payments Service

**Chức năng**: Xử lý thanh toán

- **Endpoints**:
  - `POST /payments/process` - Xử lý thanh toán
  - `GET /payments/:id` - Trạng thái thanh toán
  - `POST /payments/webhook` - Webhook từ payment gateway
- **Database**: Cloud SQL (PostgreSQL)
- **Payment Gateway**: Mock/Stripe integration
- **Port**: 8084

## Data Flow

### 1. User Registration/Login Flow

```
Client -> API Gateway -> Users Service -> Cloud SQL
                      <- JWT Token <-
```

### 2. Browse Products Flow

```
Client -> API Gateway -> Products Service -> Cloud SQL
                      <- Products List <-
```

### 3. Add to Cart Flow

```
Client -> API Gateway -> Orders Service -> Firestore
                      -> Products Service (verify stock)
```

### 4. Checkout Flow

```
Client -> API Gateway -> Orders Service -> Create Order
                      -> Payments Service -> Process Payment
                      -> Orders Service -> Update Order Status
                      -> Products Service -> Update Stock
```

## Database Design

### Users Service (PostgreSQL)

```sql
-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Addresses table
CREATE TABLE addresses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    street VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    zip_code VARCHAR(20),
    country VARCHAR(100),
    is_default BOOLEAN DEFAULT FALSE
);
```

### Products Service (PostgreSQL)

```sql
-- Categories table
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id INTEGER REFERENCES categories(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category_id INTEGER REFERENCES categories(id),
    stock_quantity INTEGER DEFAULT 0,
    image_url VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Orders Service (Firestore Collections)

```javascript
// Collection: carts
{
  userId: "user123",
  items: [
    {
      productId: "prod456",
      quantity: 2,
      price: 29.99,
      addedAt: timestamp
    }
  ],
  updatedAt: timestamp
}

// Collection: orders
{
  id: "order789",
  userId: "user123",
  items: [...],
  totalAmount: 59.98,
  status: "pending|paid|shipped|delivered|cancelled",
  shippingAddress: {...},
  paymentId: "payment123",
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### Payments Service (PostgreSQL)

```sql
-- Payments table
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(100) NOT NULL,
    user_id INTEGER NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    payment_method VARCHAR(50),
    payment_gateway VARCHAR(50),
    gateway_payment_id VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Infrastructure

### Google Cloud Services

- **GKE (Google Kubernetes Engine)**: Container orchestration
- **Cloud SQL**: PostgreSQL databases cho Users, Products, Payments
- **Firestore**: NoSQL database cho Orders
- **Artifact Registry**: Docker image storage
- **Cloud Load Balancing**: Load balancer cho external traffic
- **Cloud DNS**: Domain name resolution
- **Cloud Storage**: Static files (images, documents)
- **Cloud Build**: CI/CD pipelines
- **Cloud Monitoring**: Metrics và alerts
- **Cloud Logging**: Centralized logging

### Kubernetes Architecture

```yaml
# Namespace separation
apiVersion: v1
kind: Namespace
metadata:
  name: ecommerce
---
# Each service has:
# - Deployment (3 replicas)
# - Service (ClusterIP)
# - ConfigMap (environment config)
# - Secret (sensitive data)
```

### Network Security

- **Internal communication**: Service-to-service qua ClusterIP
- **External access**: Qua Load Balancer + API Gateway
- **Database access**: Private IP + Cloud SQL Auth Proxy
- **Secrets management**: Kubernetes Secrets + Google Secret Manager

## Deployment Strategy

### Development Environment

- **Single GKE cluster**: `ecommerce-dev-cluster`
- **Namespace**: `ecommerce-dev`
- **Database**: Development instances

### Production Environment

- **Multi-zone GKE cluster**: `ecommerce-prod-cluster`
- **Namespace**: `ecommerce-prod`
- **Database**: High availability instances
- **Auto-scaling**: HPA (Horizontal Pod Autoscaler)
- **Rolling updates**: Zero-downtime deployments

## Monitoring & Observability

### Metrics

- **Application metrics**: Request count, response time, error rate
- **Infrastructure metrics**: CPU, memory, disk usage
- **Business metrics**: Orders per minute, revenue, conversion rate

### Logging

- **Structured logging**: JSON format với correlation IDs
- **Centralized logging**: Cloud Logging
- **Log aggregation**: Per service và cross-service tracing

### Alerting

- **SLA monitoring**: 99.9% uptime target
- **Error rate alerts**: >1% error rate triggers alert
- **Performance alerts**: Response time >2s triggers alert

## Security

### Authentication & Authorization

- **JWT tokens**: Stateless authentication
- **Role-based access**: admin, customer roles
- **API rate limiting**: Prevent abuse

### Data Protection

- **Encryption at rest**: Database encryption
- **Encryption in transit**: TLS for all communications
- **PII protection**: Personal data encryption
- **GDPR compliance**: Data retention policies

## Scalability Considerations

### Horizontal Scaling

- **Stateless services**: Easy to scale replicas
- **Database sharding**: Partition data for high load
- **Caching**: Redis cho frequently accessed data

### Performance Optimization

- **CDN**: Cloud CDN cho static assets
- **Database indexing**: Optimize query performance
- **Connection pooling**: Efficient database connections
- **Async processing**: Background jobs cho heavy operations

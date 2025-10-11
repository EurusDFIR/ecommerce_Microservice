# E-commerce Microservices Architecture Diagram

## 🏗️ Complete System Architecture

```mermaid
graph TB
    subgraph "External Users"
        User[👤 End Users]
        Admin[👨‍💼 Admin]
    end

    subgraph "GitHub CI/CD"
        GHA[🔄 GitHub Actions]
        GHA -->|Build & Test| Docker[🐳 Docker Build]
        Docker -->|Push Images| AR[📦 Artifact Registry]
    end

    subgraph "Google Cloud Platform - asia-southeast1"

        subgraph "GKE Cluster - my-ecommerce-cluster"

            subgraph "Ingress Layer"
                Ingress[🌐 Ingress Controller<br/>nginx/GCP Load Balancer]
            end

            subgraph "ecommerce Namespace"

                subgraph "Users Service - Port 80"
                    US1[👤 users-service Pod 1]
                    US2[👤 users-service Pod 2]
                    USSvc[Service: users-service]
                    US1 --> USSvc
                    US2 --> USSvc
                end

                subgraph "Products Service - Port 80"
                    PS1[📦 products-service Pod 1]
                    PS2[📦 products-service Pod 2]
                    PSSvc[Service: products-service]
                    PS1 --> PSSvc
                    PS2 --> PSSvc
                end

                subgraph "Orders Service - Port 80"
                    OS1[🛒 orders-service Pod 1]
                    OS2[🛒 orders-service Pod 2]
                    OSSvc[Service: orders-service]
                    OS1 --> OSSvc
                    OS2 --> OSSvc
                end

                subgraph "Cloud SQL Proxy Sidecars"
                    Proxy1[☁️ Cloud SQL Proxy<br/>Users Service]
                    Proxy2[☁️ Cloud SQL Proxy<br/>Products Service]
                end

            end
        end

        subgraph "Databases"

            subgraph "Cloud SQL PostgreSQL"
                CSQL[🗄️ ecommerce-postgres<br/>PostgreSQL 15<br/>35.247.191.172]

                subgraph "users_db"
                    T1[users]
                    T2[user_addresses]
                    T3[user_sessions]
                    T4[user_audit_log]
                end

                subgraph "products_db"
                    T5[products]
                    T6[categories]
                    T7[product_variants]
                    T8[product_reviews]
                    T9[stock_movements]
                end
            end

            subgraph "Firestore Native Mode"
                FS[🔥 Firestore<br/>asia-southeast1]

                subgraph "Collections"
                    C1[carts]
                    C2[orders]
                end
            end
        end

        subgraph "IAM & Security"
            SA1[🔐 ecommerce-services-sa<br/>Workload Identity]
            SA2[🔐 github-actions-sa<br/>CI/CD Service Account]
            KSA[☸️ ecommerce-ksa<br/>K8s Service Account]
        end

        subgraph "Container Registry"
            AR2[📦 Artifact Registry<br/>ecommerce-images]
            IMG1[users-service:v2.4-postgres]
            IMG2[products-service:v2-postgres]
            IMG3[orders-service:v2.2-firestore]
        end

        subgraph "Monitoring & Logging"
            CM[📊 Cloud Monitoring]
            CL[📝 Cloud Logging]
        end

    end

    %% External Connections
    User -->|HTTPS| Ingress
    Admin -->|HTTPS| Ingress

    %% Ingress Routing
    Ingress -->|/users/**| USSvc
    Ingress -->|/products/**| PSSvc
    Ingress -->|/orders/**| OSSvc

    %% Service to Service Communication
    OSSvc -->|Verify JWT| USSvc
    OSSvc -->|Check Stock| PSSvc

    %% Database Connections
    US1 --> Proxy1
    US2 --> Proxy1
    Proxy1 -->|Secure Connection| CSQL

    PS1 --> Proxy2
    PS2 --> Proxy2
    Proxy2 -->|Secure Connection| CSQL

    OS1 -->|Firestore SDK| FS
    OS2 -->|Firestore SDK| FS

    %% IAM Connections
    KSA -.->|Bound to| SA1
    US1 -.->|Uses| KSA
    US2 -.->|Uses| KSA
    PS1 -.->|Uses| KSA
    PS2 -.->|Uses| KSA
    OS1 -.->|Uses| KSA
    OS2 -.->|Uses| KSA

    %% CI/CD Flow
    GHA -.->|Uses| SA2
    AR -->|Pull Images| US1
    AR -->|Pull Images| US2
    AR -->|Pull Images| PS1
    AR -->|Pull Images| PS2
    AR -->|Pull Images| OS1
    AR -->|Pull Images| OS2

    %% Monitoring
    US1 -.->|Logs & Metrics| CM
    US2 -.->|Logs & Metrics| CM
    PS1 -.->|Logs & Metrics| CM
    PS2 -.->|Logs & Metrics| CM
    OS1 -.->|Logs & Metrics| CM
    OS2 -.->|Logs & Metrics| CM
    CM -.-> CL

    %% Styling
    classDef database fill:#4285F4,stroke:#1967D2,stroke-width:2px,color:#fff
    classDef service fill:#34A853,stroke:#137333,stroke-width:2px,color:#fff
    classDef ingress fill:#FBBC04,stroke:#F29900,stroke-width:3px,color:#000
    classDef security fill:#EA4335,stroke:#C5221F,stroke-width:2px,color:#fff
    classDef cicd fill:#9334E6,stroke:#7627BB,stroke-width:2px,color:#fff

    class CSQL,FS database
    class US1,US2,PS1,PS2,OS1,OS2 service
    class Ingress ingress
    class SA1,SA2,KSA security
    class GHA,Docker,AR,AR2 cicd
```

---

## 📊 Data Flow Diagram

```mermaid
sequenceDiagram
    autonumber

    actor User as 👤 User
    participant Ingress as 🌐 Ingress
    participant US as 👤 Users Service
    participant PS as 📦 Products Service
    participant OS as 🛒 Orders Service
    participant PG as 🗄️ PostgreSQL
    participant FS as 🔥 Firestore

    %% User Registration Flow
    rect rgb(240, 248, 255)
        Note over User,PG: 1️⃣ User Registration
        User->>+Ingress: POST /users/register
        Ingress->>+US: Forward request
        US->>US: Hash password (bcrypt)
        US->>+PG: INSERT INTO users
        PG-->>-US: User created (ID: 1)
        US->>PG: INSERT INTO user_sessions
        US->>US: Generate JWT token
        US-->>-Ingress: {token, user}
        Ingress-->>-User: 201 Created
    end

    %% User Login Flow
    rect rgb(255, 250, 240)
        Note over User,PG: 2️⃣ User Login
        User->>+Ingress: POST /users/login
        Ingress->>+US: Forward request
        US->>+PG: SELECT FROM users
        PG-->>-US: User data
        US->>US: Verify password
        US->>PG: INSERT INTO user_sessions
        US->>US: Generate JWT token
        US-->>-Ingress: {token, user}
        Ingress-->>-User: 200 OK
    end

    %% Browse Products Flow
    rect rgb(240, 255, 240)
        Note over User,PG: 3️⃣ Browse Products
        User->>+Ingress: GET /products?category=Electronics
        Ingress->>+PS: Forward request
        PS->>+PG: SELECT FROM products JOIN categories
        PG-->>-PS: Product list (5 items)
        PS-->>-Ingress: {products: [...]}
        Ingress-->>-User: 200 OK
    end

    %% Add to Cart Flow
    rect rgb(255, 240, 245)
        Note over User,FS: 4️⃣ Add to Cart
        User->>+Ingress: POST /orders/cart<br/>{productId: 1, quantity: 2}<br/>Authorization: Bearer TOKEN
        Ingress->>+OS: Forward with JWT
        OS->>+US: GET /users/verify-token
        US->>PG: Verify session
        US-->>-OS: {userId: 1, email: "user@example.com"}
        OS->>+PS: GET /products/1/stock
        PS->>+PG: SELECT stock_quantity
        PG-->>-PS: {inStock: true, quantity: 50}
        PS-->>-OS: Product available
        OS->>+FS: Update cart document
        FS-->>-OS: Cart updated
        OS-->>-Ingress: {success: true, cart: {...}}
        Ingress-->>-User: 200 OK
    end

    %% View Cart Flow
    rect rgb(248, 240, 255)
        Note over User,FS: 5️⃣ View Cart
        User->>+Ingress: GET /orders/cart<br/>Authorization: Bearer TOKEN
        Ingress->>+OS: Forward with JWT
        OS->>+US: Verify JWT
        US-->>-OS: {userId: 1}
        OS->>+FS: Get cart document
        FS-->>-OS: Cart data
        OS-->>-Ingress: {cart: {items: [...], totalAmount: 2599.98}}
        Ingress-->>-User: 200 OK
    end

    %% Checkout Flow
    rect rgb(255, 248, 240)
        Note over User,FS: 6️⃣ Checkout (Create Order)
        User->>+Ingress: POST /orders<br/>Authorization: Bearer TOKEN
        Ingress->>+OS: Forward with JWT
        OS->>US: Verify JWT
        US-->>OS: User verified
        OS->>FS: Get cart
        FS-->>OS: Cart items
        OS->>PS: Verify stock for all items
        PS->>PG: Check stock_quantity
        PG-->>PS: Stock available
        PS-->>OS: All items available
        OS->>+FS: Create order document
        FS-->>-OS: Order created (ID: ORD-001)
        OS->>FS: Clear cart
        OS-->>-Ingress: {orderId: "ORD-001", status: "pending"}
        Ingress-->>-User: 201 Created
    end
```

---

## 🔄 CI/CD Pipeline Flow

```mermaid
flowchart TD
    Start([👨‍💻 Developer Push Code]) --> PR[📝 Create Pull Request]

    PR --> CI{🧪 CI Pipeline<br/>GitHub Actions}

    CI -->|Run Tests| T1[Unit Tests]
    CI -->|Code Quality| T2[ESLint/Prettier]
    CI -->|Security| T3[Trivy Scan]
    CI -->|DB Validation| T4[Migration Test]

    T1 --> Check{All Checks<br/>Passed?}
    T2 --> Check
    T3 --> Check
    T4 --> Check

    Check -->|❌ Failed| Fix[🔧 Fix Issues]
    Fix --> PR

    Check -->|✅ Passed| Review[👥 Code Review]
    Review -->|Approved| Merge[🔀 Merge to Main]

    Merge --> CD{🚀 CD Pipeline<br/>GitHub Actions}

    CD --> B1[🏗️ Build Docker Images]
    B1 --> B2[📦 Push to Artifact Registry<br/>Tag: YYYYMMDD-HHMMSS-SHA]

    B2 --> D1[☸️ Deploy to GKE]
    D1 --> D2[🔄 Rolling Update<br/>Zero Downtime]

    D2 --> V1{🏥 Health Checks}
    V1 -->|❌ Failed| RB[⏮️ Auto Rollback]
    RB --> Alert1[🚨 Alert Team]

    V1 -->|✅ Passed| E2E[🧪 E2E Tests]
    E2E -->|❌ Failed| RB
    E2E -->|✅ Passed| Done([✅ Deployment Complete])

    Done --> Monitor[📊 Monitor Metrics]

    style Start fill:#4285F4,color:#fff
    style Done fill:#34A853,color:#fff
    style RB fill:#EA4335,color:#fff
    style CI fill:#FBBC04,color:#000
    style CD fill:#FBBC04,color:#000
```

---

## 🗄️ Database Schema Diagram

```mermaid
erDiagram
    %% Users Database
    USERS ||--o{ USER_ADDRESSES : has
    USERS ||--o{ USER_SESSIONS : has
    USERS ||--o{ USER_AUDIT_LOG : tracks
    USERS ||--o{ ORDERS : places

    USERS {
        int id PK
        string email UK
        string password_hash
        string full_name
        enum role
        timestamp created_at
        timestamp updated_at
    }

    USER_ADDRESSES {
        int id PK
        int user_id FK
        string address_type
        string street_address
        string city
        string country
        bool is_default
    }

    USER_SESSIONS {
        int id PK
        int user_id FK
        string token_hash
        timestamp expires_at
        timestamp created_at
    }

    USER_AUDIT_LOG {
        int id PK
        int user_id FK
        string action
        jsonb metadata
        timestamp created_at
    }

    %% Products Database
    CATEGORIES ||--o{ PRODUCTS : contains
    PRODUCTS ||--o{ PRODUCT_VARIANTS : has
    PRODUCTS ||--o{ PRODUCT_REVIEWS : receives
    PRODUCTS ||--o{ STOCK_MOVEMENTS : tracks
    PRODUCTS ||--o{ ORDER_ITEMS : contains

    CATEGORIES {
        int id PK
        string name UK
        string slug UK
        text description
        timestamp created_at
    }

    PRODUCTS {
        int id PK
        int category_id FK
        string name
        string sku UK
        text description
        decimal base_price
        int stock_quantity
        tsvector search_vector
        timestamp created_at
    }

    PRODUCT_VARIANTS {
        int id PK
        int product_id FK
        string variant_name
        decimal price_modifier
        int stock_quantity
    }

    PRODUCT_REVIEWS {
        int id PK
        int product_id FK
        int user_id FK
        int rating
        text comment
        timestamp created_at
    }

    STOCK_MOVEMENTS {
        int id PK
        int product_id FK
        int quantity_change
        enum movement_type
        text notes
        timestamp created_at
    }

    %% Firestore Collections (Logical)
    ORDERS ||--o{ ORDER_ITEMS : contains
    CARTS ||--o{ CART_ITEMS : contains

    ORDERS {
        string orderId PK
        int userId
        string status
        decimal totalAmount
        timestamp createdAt
        timestamp updatedAt
    }

    ORDER_ITEMS {
        int productId
        int quantity
        decimal price
        string productName
    }

    CARTS {
        string cartId PK
        int userId
        decimal totalAmount
        timestamp updatedAt
    }

    CART_ITEMS {
        int productId
        int quantity
        decimal price
        string productName
    }
```

---

## 🔐 Security Architecture

```mermaid
flowchart TB
    subgraph "External Layer"
        User[👤 User]
        Attacker[🔴 Potential Attacker]
    end

    subgraph "Security Layers"

        subgraph "Network Security"
            FW[🛡️ GCP Firewall Rules]
            LB[⚖️ Load Balancer<br/>DDoS Protection]
        end

        subgraph "Application Security"
            JWT[🔑 JWT Authentication]
            CORS[🚫 CORS Policy]
            RateLimit[⏱️ Rate Limiting]
            Validation[✅ Input Validation]
        end

        subgraph "Infrastructure Security"
            WI[🆔 Workload Identity]
            IAM[🔐 IAM Policies]
            Secrets[🔒 K8s Secrets]
            Encryption[🔐 Encryption at Rest]
        end

        subgraph "Database Security"
            SQLProxy[☁️ Cloud SQL Proxy]
            PrivateIP[🔒 Private IP]
            BackupEnc[💾 Encrypted Backups]
        end

    end

    User -->|HTTPS Only| FW
    Attacker -.->|Blocked| FW

    FW --> LB
    LB --> JWT
    JWT --> CORS
    CORS --> RateLimit
    RateLimit --> Validation

    Validation --> WI
    WI --> IAM
    IAM --> Secrets

    Secrets --> SQLProxy
    SQLProxy --> PrivateIP
    PrivateIP --> Encryption
    Encryption --> BackupEnc

    style FW fill:#EA4335,color:#fff
    style JWT fill:#4285F4,color:#fff
    style WI fill:#34A853,color:#fff
    style SQLProxy fill:#FBBC04,color:#000
```

---

## 📈 Scalability Architecture

```mermaid
graph TB
    subgraph "Auto-Scaling Configuration"

        subgraph "Horizontal Pod Autoscaling"
            HPA1[Users Service HPA<br/>Min: 2, Max: 10<br/>CPU: 70%, Memory: 80%]
            HPA2[Products Service HPA<br/>Min: 2, Max: 10<br/>CPU: 70%, Memory: 80%]
            HPA3[Orders Service HPA<br/>Min: 2, Max: 10<br/>CPU: 70%, Memory: 80%]
        end

        subgraph "GKE Cluster Autoscaling"
            NA[Node Auto-Scaling<br/>Min Nodes: 3<br/>Max Nodes: 10]
        end

        subgraph "Database Scaling"
            CSQL[Cloud SQL<br/>Vertical Scaling<br/>Read Replicas]
            FS[Firestore<br/>Auto-Scaling<br/>Global Distribution]
        end

    end

    Load[📊 High Traffic Load] --> HPA1
    Load --> HPA2
    Load --> HPA3

    HPA1 -->|Scale Pods| NA
    HPA2 -->|Scale Pods| NA
    HPA3 -->|Scale Pods| NA

    NA -->|Add Nodes| GKE[☸️ GKE Cluster]

    GKE --> CSQL
    GKE --> FS

    style Load fill:#EA4335,color:#fff
    style GKE fill:#4285F4,color:#fff
    style CSQL fill:#34A853,color:#fff
    style FS fill:#FBBC04,color:#000
```

---

## 🔍 Monitoring & Observability

```mermaid
graph TB
    subgraph "Application Layer"
        US[Users Service]
        PS[Products Service]
        OS[Orders Service]
    end

    subgraph "Metrics Collection"
        Prom[📊 Prometheus<br/>Time-Series Metrics]
        CM[📊 Cloud Monitoring<br/>GCP Metrics]
    end

    subgraph "Logging"
        CL[📝 Cloud Logging<br/>Centralized Logs]
        Loki[📝 Loki<br/>Log Aggregation]
    end

    subgraph "Tracing"
        Trace[🔍 Cloud Trace<br/>Distributed Tracing]
    end

    subgraph "Visualization"
        Grafana[📈 Grafana Dashboards]
        Console[🖥️ GCP Console]
    end

    subgraph "Alerting"
        AM[🚨 Alertmanager]
        Slack[💬 Slack Notifications]
        Email[📧 Email Alerts]
    end

    US --> Prom
    PS --> Prom
    OS --> Prom

    US --> CM
    PS --> CM
    OS --> CM

    US --> CL
    PS --> CL
    OS --> CL

    US --> Trace
    PS --> Trace
    OS --> Trace

    Prom --> Grafana
    CM --> Console
    CL --> Grafana
    Loki --> Grafana

    Grafana --> AM
    CM --> AM

    AM --> Slack
    AM --> Email

    style Grafana fill:#F46800,color:#fff
    style AM fill:#EA4335,color:#fff
```

---

## 🌍 Multi-Region Architecture (Future)

```mermaid
graph TB
    subgraph "Global Load Balancer"
        GLB[🌐 Cloud Load Balancer<br/>Anycast IP]
    end

    subgraph "Asia - Primary Region"
        subgraph "asia-southeast1"
            GKE1[☸️ GKE Cluster 1]
            SQL1[🗄️ Cloud SQL Primary]
            FS1[🔥 Firestore Primary]
        end
    end

    subgraph "US - Secondary Region"
        subgraph "us-central1"
            GKE2[☸️ GKE Cluster 2]
            SQL2[🗄️ Cloud SQL Replica]
            FS2[🔥 Firestore Regional]
        end
    end

    subgraph "Europe - Tertiary Region"
        subgraph "europe-west1"
            GKE3[☸️ GKE Cluster 3]
            SQL3[🗄️ Cloud SQL Replica]
            FS3[🔥 Firestore Regional]
        end
    end

    Users[🌏 Global Users] --> GLB

    GLB -->|Geo-Routing| GKE1
    GLB -->|Geo-Routing| GKE2
    GLB -->|Geo-Routing| GKE3

    GKE1 --> SQL1
    GKE1 --> FS1

    GKE2 --> SQL2
    GKE2 --> FS2

    GKE3 --> SQL3
    GKE3 --> FS3

    SQL1 -.->|Replication| SQL2
    SQL1 -.->|Replication| SQL3

    FS1 -.->|Multi-Region Sync| FS2
    FS1 -.->|Multi-Region Sync| FS3

    style GLB fill:#4285F4,color:#fff
    style GKE1 fill:#34A853,color:#fff
    style GKE2 fill:#34A853,color:#fff
    style GKE3 fill:#34A853,color:#fff
```

---

## 📝 Component Summary

| Component             | Technology         | Purpose                           | Status        |
| --------------------- | ------------------ | --------------------------------- | ------------- |
| **API Gateway**       | Ingress Controller | Route external traffic            | ⏳ Pending    |
| **Users Service**     | Node.js + Express  | Authentication & user management  | ✅ Running    |
| **Products Service**  | Node.js + Express  | Product catalog management        | ✅ Running    |
| **Orders Service**    | Node.js + Express  | Order & cart management           | ✅ Running    |
| **Cloud SQL**         | PostgreSQL 15      | Relational data storage           | ✅ Running    |
| **Firestore**         | NoSQL Database     | Document storage for carts/orders | ✅ Running    |
| **GKE**               | Kubernetes         | Container orchestration           | ✅ Running    |
| **Artifact Registry** | Container Registry | Docker image storage              | ✅ Configured |
| **GitHub Actions**    | CI/CD              | Automated deployment pipeline     | ✅ Configured |
| **Cloud SQL Proxy**   | Sidecar Container  | Secure database connection        | ✅ Running    |
| **Workload Identity** | IAM                | Secure service authentication     | ✅ Configured |

---

**Last Updated:** October 11, 2025  
**Architecture Version:** v2.0  
**Status:** Production Ready (Ingress Pending)

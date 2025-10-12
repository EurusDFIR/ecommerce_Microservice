# E-Commerce Microservices

[![CI - Pull Request](https://github.com/EurusDFIR/ecommerce_Microservice/actions/workflows/ci-pull-request.yml/badge.svg)](https://github.com/EurusDFIR/ecommerce_Microservice/actions/workflows/ci-pull-request.yml)
[![CD - Deploy to GKE](https://github.com/EurusDFIR/ecommerce_Microservice/actions/workflows/cd-deploy.yml/badge.svg)](https://github.com/EurusDFIR/ecommerce_Microservice/actions/workflows/cd-deploy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A scalable e-commerce platform built with microservices architecture on Google Cloud Platform (GCP). This project demonstrates modern cloud-native development practices with automated CI/CD, container orchestration, and multi-database support.

## 🚀 Live Demo

**🌐 Public API Endpoint:** http://34.143.235.74

**📱 Quick Test:**

```bash
curl http://34.143.235.74/health
curl http://34.143.235.74/products
```

**Status:** 🟢 **DEPLOYED & RUNNING** on Google Kubernetes Engine (GKE)

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Quick Start](#quick-start)
- [API Documentation](#api-documentation)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)
- [Authors](#authors)

## ✨ Features

- **Microservices Architecture**: Independently deployable services
- **Multi-Database Support**: PostgreSQL for relational data, Firestore for NoSQL
- **Automated CI/CD**: GitHub Actions with comprehensive testing
- **Container Orchestration**: Kubernetes with auto-scaling and self-healing
- **API Gateway**: Centralized API management
- **Monitoring & Logging**: Cloud-native observability
- **Security**: JWT authentication and secure communication

## 🏗️ Architecture

### Core Services

| Service              | Technology      | Database   | Description                     |
| -------------------- | --------------- | ---------- | ------------------------------- |
| **Users Service**    | Node.js/Express | PostgreSQL | User management, authentication |
| **Products Service** | Node.js/Express | PostgreSQL | Product catalog, inventory      |
| **Orders Service**   | Node.js/Express | Firestore  | Shopping cart, order processing |

### Infrastructure Diagram

```
┌─────────────────┐    ┌─────────────────┐
│   API Gateway   │    │  Cloud Load    │
│                 │    │   Balancer     │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          ▼                      ▼
┌─────────────────┐    ┌─────────────────┐
│  Users Service  │    │ Products Service│
│                 │    │                 │
│   PostgreSQL    │    │   PostgreSQL    │
└─────────────────┘    └─────────────────┘
          │
          ▼
┌─────────────────┐
│ Orders Service  │
│                 │
│    Firestore    │
└─────────────────┘
```

_For detailed architecture, see [docs/architecture.md](docs/architecture.md) and [docs/ARCHITECTURE_DIAGRAM.md](docs/ARCHITECTURE_DIAGRAM.md)_

## 🛠️ Technology Stack

### Backend & Runtime

- **Node.js** 18+ with Express.js
- **Docker** for containerization
- **Kubernetes** (GKE) for orchestration

### Databases

- **Cloud SQL (PostgreSQL)** for relational data
- **Firestore** for document-based data

### Cloud Services

- **Google Cloud Platform**
  - GKE (Kubernetes Engine)
  - Cloud SQL
  - Firestore
  - Cloud Build
  - Artifact Registry
  - Cloud Monitoring

### DevOps & CI/CD

- **GitHub Actions** for automation
- **kubectl** for cluster management
- **Docker Compose** for local development

## 🚀 Quick Start

### Prerequisites

- Google Cloud SDK (`gcloud` CLI)
- Docker Desktop
- `kubectl` configured for GKE
- Node.js 18+
- Git

### 1. Clone the Repository

```bash
git clone https://github.com/EurusDFIR/ecommerce_Microservice.git
cd ecommerce_Microservice
```

### 2. Configure Google Cloud

```bash
# Authenticate
gcloud auth login

# Set project
gcloud config set project ecommerce-micro-0037

# Configure kubectl for GKE cluster
gcloud container clusters get-credentials my-ecommerce-cluster --region asia-southeast1
```

### 3. Deploy to GKE

```bash
# Deploy all services
kubectl apply -f infrastructure/k8s/

# Check deployment status
kubectl get pods -n ecommerce
kubectl get services -n ecommerce
```

### 4. Test the APIs

```bash
# Health check
curl http://34.143.235.74/health

# Get products
curl http://34.143.235.74/products

# Get categories
curl http://34.143.235.74/categories
```

## 📚 API Documentation

### Public Endpoints (LoadBalancer)

| Method | Endpoint            | Description             |
| ------ | ------------------- | ----------------------- |
| GET    | `/health`           | Service health check    |
| GET    | `/products`         | List all products       |
| GET    | `/products/{id}`    | Get product details     |
| GET    | `/categories`       | List product categories |
| GET    | `/search?q={query}` | Search products         |

### Internal Endpoints (ClusterIP)

| Service | Endpoint         | Description              |
| ------- | ---------------- | ------------------------ |
| Users   | `/auth/register` | User registration        |
| Users   | `/auth/login`    | User authentication      |
| Users   | `/users/me`      | Get user profile         |
| Orders  | `/cart`          | Shopping cart operations |
| Orders  | `/orders`        | Order management         |

_Note: Users and Orders services are internal only. For full API testing, use Postman collection in `postman/` directory._

## 💻 Development

### Local Development Setup

```bash
# Install dependencies for all services
cd services/users-service && npm install
cd ../products-service && npm install
cd ../orders-service && npm install

# Start local databases
docker-compose up -d postgres firestore-emulator

# Run services locally
npm run dev  # in each service directory
```

### Project Structure

```
ecommerce_Microservice/
├── docs/                     # Documentation
│   ├── architecture.md       # Architecture details
│   └── ARCHITECTURE_DIAGRAM.md # Visual diagrams
├── services/                 # Microservices
│   ├── users-service/        # User management
│   ├── products-service/     # Product catalog
│   └── orders-service/       # Order processing
├── infrastructure/           # Infrastructure as Code
│   └── k8s/                  # Kubernetes manifests
├── postman/                  # API testing collections
├── scripts/                  # Utility scripts
└── README.md
```

### Testing

```bash
# Run unit tests
npm test

# Run integration tests
npm run test:integration

# Run E2E tests
npm run test:e2e
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTORS.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow ESLint configuration
- Write tests for new features
- Update documentation as needed
- Ensure all CI checks pass

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

This project was developed by:

- **Lê Văn Hoàng**
- **Nguyễn Tuấn Việt**
- **Diệp Đại Lê Hoài**
- **Nguyễn Ngọc Hòa**
- **Đoàn Thanh Phúc**
- **Nguyễn Văn Linh**

_For detailed contributor information, see [CONTRIBUTORS.md](CONTRIBUTORS.md)_

---

**Built with ❤️ on Google Cloud Platform**

_Last updated: October 12, 2025_

# E-Commerce Microservices trên Google Cloud Platform

![CI - Pull Request](https://github.com/YOUR_USERNAME/e-commerce-microservice/actions/workflows/ci-pull-request.yml/badge.svg)
![CD - Deploy to GKE](https://github.com/YOUR_USERNAME/e-commerce-microservice/actions/workflows/cd-deploy.yml/badge.svg)
![Database Migrations](https://github.com/YOUR_USERNAME/e-commerce-microservice/actions/workflows/database-migrations.yml/badge.svg)

## 🎉 Dự án đã LIVE!

**🌐 API URL:** http://34.143.235.74

**📱 Test ngay:**

```bash
curl http://34.143.235.74/products
curl http://34.143.235.74/categories
```

**CI/CD Status:** ✅ Automated with GitHub Actions

## Mô tả dự án

Đây là một hệ thống E-commerce được xây dựng theo kiến trúc Microservices trên Google Cloud Platform (GCP). Dự án này thực hiện triển khai một nền tảng thương mại điện tử với các dịch vụ độc lập, có khả năng mở rộng và bảo trì cao.

**Status:** 🟢 **DEPLOYED & RUNNING** on GKE

## Kiến trúc hệ thống

### Các Microservices chính:

1. **Users Service** - Quản lý người dùng (đăng ký, đăng nhập, hồ sơ)
2. **Products Service** - Quản lý sản phẩm (danh sách, chi tiết, tồn kho)
3. **Orders Service** - Xử lý đơn hàng (giỏ hàng, đặt hàng, lịch sử)
4. **Payments Service** - Xử lý thanh toán

### Công nghệ sử dụng:

- **Backend**: Node.js + Express
- **Database**: Cloud SQL (PostgreSQL), Firestore
- **Container**: Docker
- **Orchestration**: Google Kubernetes Engine (GKE)
- **CI/CD**: Cloud Build
- **API Gateway**: Cloud Endpoints
- **Storage**: Google Cloud Storage
- **Monitoring**: Cloud Monitoring & Logging

## Cấu trúc thư mục

```
e_commerce_microservice/
├── docs/                     # Tài liệu thiết kế
├── services/                 # Các microservices
│   ├── users-service/
│   ├── products-service/
│   ├── orders-service/
│   └── payments-service/
├── infrastructure/          # Cấu hình Kubernetes & Terraform
├── scripts/                 # Scripts tiện ích
└── README.md
```

## Yêu cầu hệ thống

- Google Cloud SDK (gcloud CLI)
- Docker Desktop
- kubectl
- Node.js 18+
- Git

## Bắt đầu nhanh

### 1. Cấu hình môi trường

```bash
# Đăng nhập Google Cloud
gcloud auth login

# Tạo dự án mới
gcloud projects create my-ecommerce-project --name="E-commerce Microservices"

# Thiết lập dự án làm việc
gcloud config set project my-ecommerce-project
```

### 2. Kích hoạt APIs cần thiết

```bash
gcloud services enable container.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable sql-component.googleapis.com
```

### 3. Triển khai

Chi tiết xem trong file `TODO.md`

## CI/CD Pipeline

✅ **Automated CI/CD with GitHub Actions**

Our project uses GitHub Actions for continuous integration and deployment:

- 🧪 **PR Validation** - Automated testing on pull requests
- 🚀 **Auto Deploy** - Push to main triggers deployment to GKE
- 🗄️ **Database Migrations** - Safe, automated schema updates
- 🔥 **Hotfix Workflow** - Emergency deployment with auto-rollback

**📚 Documentation:**

- [CI/CD Pipeline Guide](docs/CI_CD_PIPELINE.md)
- [GitHub Actions Setup](docs/GITHUB_ACTIONS_SETUP.md)

**Workflow Status:**

- CI checks run on every PR
- Deployment to GKE on merge to main
- E2E tests validate deployments
- All workflows visible in [Actions tab](../../actions)

## Tài liệu

### Deployment & Operations

- [Database Testing Status](docs/DATABASE_TESTING_STATUS.md) - E2E test results
- [Database Deployment Success](docs/DATABASE_DEPLOYMENT_SUCCESS.md) - Migration status
- [CI/CD Pipeline Documentation](docs/CI_CD_PIPELINE.md) - **⭐ NEW**
- [GitHub Actions Setup Guide](docs/GITHUB_ACTIONS_SETUP.md) - **⭐ NEW**

### Architecture & API

- [TODO List](TODO.md) - Development roadmap
- [Thiết kế kiến trúc](docs/architecture.md)
- [API Documentation](docs/api.md)
- [Deployment Guide](docs/deployment.md)

## Tác giả

- Tên: [Tên của bạn]

  - Lê Văn Hoàng

  - Nguyễn Tuấn Việt

  - Diệp Đại Lê Hoài

  - Nguyễn Ngọc Hòa

  - Đoàn Thanh Phúc
 
  - Ghi tiếp tên vào đây

- Email: [Email của bạn]
- GitHub: [GitHub username]

## License

MIT License
## Testing CI Pipeline

The CI pipeline is automated using GitHub Actions and runs on every pull request and push to the main branch. It performs the following tasks:

- Lints and builds all microservices.
- Runs unit and integration tests.
- Checks code quality and formatting.

**How to test the CI pipeline:**

1. **Create a Pull Request:** Push your changes to a new branch and open a pull request. The CI pipeline will automatically run and you can view the results in the "Checks" tab of your PR.
2. **Manual Trigger:** You can manually trigger the workflow from the [Actions tab](https://github.com/YOUR_USERNAME/e-commerce-microservice/actions) in GitHub.
3. **Check Status:** Look for the CI badge at the top of this README or visit the [CI workflow logs](https://github.com/YOUR_USERNAME/e-commerce-microservice/actions/workflows/ci-pull-request.yml).

**Example:**

```bash
# After pushing your branch, open a PR and check the status:
# (No local command needed, all runs on GitHub Actions)
## CI/CD Pipeline Status

✅ **Priority #2 - COMPLETED**

All GitHub Actions workflows are configured and tested:
- CI workflow triggers on all pull requests
- All 7 status checks must pass before merging
- Branch protection rules are active on main branch

Last updated: 2025-10-11 15:06:50

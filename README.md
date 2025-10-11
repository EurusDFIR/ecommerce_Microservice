# E-Commerce Microservices trên Google Cloud Platform

## 🎉 Dự án đã LIVE!

**🌐 API URL:** http://34.143.235.74

**📱 Test ngay:**

```bash
curl http://34.143.235.74/products
curl http://34.143.235.74/categories
```

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

## Tài liệu

- [TODO List](TODO.md) - Danh sách công việc cần thực hiện
- [Thiết kế kiến trúc](docs/architecture.md)
- [API Documentation](docs/api.md)
- [Deployment Guide](docs/deployment.md)

## Tác giả

- Tên: [Tên của bạn]

  - Lê Văn Hoàng

  - Nguyễn Tuấn Việt

  - Diệp Đại Lê Hoài

  - Nguyễn Ngọc Hòa

  - Ghi tiếp tên vào đây

- Email: [Email của bạn]
- GitHub: [GitHub username]

## License

MIT License



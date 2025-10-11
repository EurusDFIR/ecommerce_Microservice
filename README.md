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
- **ContainLinh

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

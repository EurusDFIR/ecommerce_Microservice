# Báo cáo tiểu luận cuối kỳ

## Xây dựng hệ thống E-commerce với kiến trúc Microservices theo chuẩn Best Practice trên Google Cloud Platform

---

### 1. Lời Mở Đầu

#### Bối cảnh

Sự phát triển mạnh mẽ của các ứng dụng web hiện đại đã đặt ra nhiều thách thức về khả năng mở rộng, độ tin cậy và tốc độ triển khai. Kiến trúc nguyên khối (Monolithic) truyền thống thường gặp khó khăn khi cần mở rộng, bảo trì hoặc tích hợp công nghệ mới. Điều này thúc đẩy sự chuyển dịch sang kiến trúc Microservices.

#### Mục tiêu của đồ án

1. Áp dụng kiến trúc Microservices để xây dựng hệ thống E-commerce linh hoạt, dễ mở rộng.
2. Sử dụng containerization (Docker) và điều phối (Kubernetes/GKE) để vận hành hệ thống đáng tin cậy.
3. Xây dựng quy trình phát triển và triển khai phần mềm tự động (CI/CD) theo chuẩn DevOps hiện đại.

---

### 2. Thiết Kế Kiến Trúc Hệ Thống (Architecture Design)

#### Sơ đồ kiến trúc tổng quan

```
sequenceDiagram
    participant User
    participant LB as Load Balancer
    participant GKE as GKE Cluster
    participant Users as Users Service
    participant Products as Products Service
    participant Orders as Orders Service
    participant SQL as Cloud SQL
    participant Firestore as Firestore
    participant CI as CI/CD Pipeline
    User->>LB: Gửi request
    LB->>GKE: Chuyển tiếp request
    GKE->>Users: Xác thực
    GKE->>Products: Kiểm tra sản phẩm
    GKE->>Orders: Đặt hàng
    Orders->>Firestore: Lưu đơn hàng
    Users->>SQL: Truy vấn thông tin
    Products->>SQL: Truy vấn sản phẩm
    CI->>GKE: Tự động deploy
```

#### Mô tả các thành phần

- **User:** Người dùng cuối truy cập hệ thống qua trình duyệt/mobile.
- **Load Balancer:** Phân phối traffic đến các pod trong GKE, đảm bảo tính sẵn sàng.
- **GKE Cluster:** Chạy các microservices (Users, Products, Orders) dưới dạng container.
- **Cloud SQL:** Lưu trữ dữ liệu quan trọng (users, products) với tính toàn vẹn ACID.
- **Firestore:** Lưu trữ đơn hàng, giỏ hàng với khả năng mở rộng ghi linh hoạt.
- **CI/CD Pipeline:** Tự động hóa build, test, deploy qua GitHub Actions.

#### Luồng dữ liệu tiêu biểu

Khi người dùng đặt hàng, request đi từ Load Balancer vào Orders Service. Orders Service gọi nội bộ đến Users Service để xác thực, Products Service để kiểm tra thông tin sản phẩm, cuối cùng lưu đơn hàng vào Firestore.

---

### 3. Công Nghệ & Triển Khai Chi Tiết (Core Technologies & Implementation)

#### 3.1. Trụ cột 1: Kiến trúc Microservices & Data

- **Phân tách dịch vụ:**
  - `Users Service`: Quản lý tài khoản, xác thực, thông tin người dùng.
  - `Products Service`: Quản lý sản phẩm, tồn kho, danh mục.
  - `Orders Service`: Quản lý giỏ hàng, đơn hàng, lịch sử giao dịch.
- **Polyglot Persistence:**
  - **Cloud SQL** (PostgreSQL): Chọn cho Users/Products vì cần tính toàn vẹn dữ liệu, giao dịch ACID, dễ truy vấn phức tạp.
  - **Firestore**: Chọn cho Orders vì cần lưu trữ linh hoạt, mở rộng ghi, không cần join phức tạp. Đây là best practice cho hệ thống có workload ghi lớn và dữ liệu phi cấu trúc.

#### 3.2. Trụ cột 2: Containerization & Điều phối

- **Docker:**
  - Đóng gói ứng dụng thành container, đảm bảo môi trường nhất quán từ dev đến prod.
  - Best practice: Sử dụng minimal base image (alpine, slim), chạy non-root user để tăng bảo mật.
- **Google Kubernetes Engine (GKE):**
  - Chọn GKE vì cung cấp khả năng tự phục hồi (self-healing), cân bằng tải (load balancing), co giãn (scaling) tự động.
  - GKE tích hợp tốt với các dịch vụ GCP khác, dễ quản lý, tiết kiệm chi phí vận hành.

#### 3.3. Trụ cột 3: Tự động hóa & DevOps (CI/CD)

- **Quy trình CI/CD:**
  - Sử dụng GitHub Actions để tự động hóa toàn bộ pipeline.
  - **CI:** Tự động chạy test, kiểm tra code quality khi có Pull Request.
  - **CD:** Tự động build Docker image, push lên Artifact Registry, deploy lên GKE khi merge vào `main`.
  - Lợi ích: Tăng tốc độ phát triển, giảm thiểu lỗi, đảm bảo chất lượng và tính nhất quán.

#### 3.4. Trụ cột 4: An ninh & Giám sát

- **Bảo mật kết nối:**
  - Sử dụng Cloud SQL Auth Proxy để kết nối an toàn từ GKE đến Cloud SQL, tránh lộ thông tin truy cập DB.
  - Đây là best practice được Google khuyến nghị cho production.
- **Quản lý Bí mật:**
  - Sử dụng Kubernetes Secrets và biến môi trường để quản lý thông tin nhạy cảm (DB password, service account key), không hard-code trong code.
- **Monitoring & Logging:**
  - Sử dụng Cloud Operations Suite (Cloud Monitoring, Cloud Logging) để theo dõi sức khỏe hệ thống, cảnh báo lỗi, truy vết sự cố.

---

### 4. Kiểm Thử & Đánh Giá (Testing & Evaluation)

- **Kiểm thử End-to-End (E2E):**
  - Xây dựng script `test-e2e.sh` kiểm tra luồng người dùng: Đăng ký → Đăng nhập → Đặt hàng → Kiểm tra đơn hàng.
  - Sử dụng Postman Collection với 27 requests, 81 test scripts để kiểm tra toàn bộ API.
- **Kết quả Demo:**
  - Demo luồng hoạt động qua Postman, trình diễn CI/CD tự động build, test, deploy và kiểm thử E2E.

---

### 5. Kết Luận

- **Tổng kết kết quả đạt được:**
  - Đã xây dựng hệ thống E-commerce microservices trên GCP theo chuẩn best practice.
  - Đã triển khai CI/CD tự động hóa toàn bộ quy trình phát triển và vận hành.
  - Đã đảm bảo bảo mật, giám sát, khả năng mở rộng và tính sẵn sàng cao.
- **Bài học kinh nghiệm:**
  - Quản lý secrets và credentials là vấn đề quan trọng nhất.
  - CI/CD giúp phát hiện lỗi sớm, tiết kiệm thời gian vận hành.
  - Việc tích hợp nhiều dịch vụ cloud đòi hỏi hiểu sâu về IAM, networking và bảo mật.
- **Hướng phát triển tương lai:**
  - Triển khai Service Mesh (Istio) để quản lý traffic nội bộ, bảo mật nâng cao.
  - Thêm caching với Redis để tăng tốc độ truy vấn.
  - Xây dựng dashboard giám sát chi tiết với Grafana, Prometheus.

---

### 6. Phụ Lục

#### Ví dụ file cấu hình tiêu biểu

##### `deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: users-service-postgres-deployment
  namespace: ecommerce
spec:
  replicas: 2
  selector:
    matchLabels:
      app: users-service
  template:
    metadata:
      labels:
        app: users-service
    spec:
      containers:
        - name: users-service
          image: asia-southeast1-docker.pkg.dev/ecommerce-micro-0037/ecommerce-images/users-service:latest
          ports:
            - containerPort: 8081
          env:
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: cloudsql-db-credentials
                  key: host
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: cloudsql-db-credentials
                  key: password
```

##### `ci-pull-request.yml`

```yaml
name: CI - Pull Request
on:
  pull_request:
    branches: [main]

jobs:
  lint-and-format:
    name: Code Quality
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "18"
      - name: Install dependencies
        run: npm ci
      - name: Run ESLint
        run: npm run lint
```

---

**Kết thúc báo cáo.**

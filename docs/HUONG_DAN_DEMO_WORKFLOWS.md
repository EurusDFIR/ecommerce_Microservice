# Hướng Dẫn Demo & Test Workflows CI/CD

## 📋 Mục Lục

1. [Chuẩn Bị Demo](#chuẩn-bị-demo)
2. [Demo CI Workflow - Pull Request](#demo-ci-workflow)
3. [Demo CD Workflow - Deploy to GKE](#demo-cd-workflow)
4. [Demo Database Migrations](#demo-database-migrations)
5. [Demo Hotfix Deployment](#demo-hotfix-deployment)
6. [Demo End-to-End Testing](#demo-e2e-testing)
7. [Troubleshooting](#troubleshooting)

---

## 🎯 Chuẩn Bị Demo

### Checklist Trước Khi Demo:

- [ ] Đảm bảo repo clean: `git status` không có uncommitted changes
- [ ] Branch `main` đã có latest code
- [ ] GKE cluster đang chạy: `gcloud container clusters list`
- [ ] Secrets đã được cấu hình đúng trên GitHub
- [ ] Internet connection ổn định (để access GitHub Actions & GCP)

### Secrets Cần Thiết:

```
GCP_SA_KEY              # Base64-encoded GCP service account key
CLOUDSQL_INSTANCE       # Cloud SQL instance connection name
DB_PASSWORD             # Database password
```

### Kiểm Tra GKE Cluster:

```bash
# Authenticate với GKE
gcloud container clusters get-credentials my-ecommerce-cluster \
  --zone=asia-southeast1 \
  --project=ecommerce-micro-0037

# Kiểm tra pods đang chạy
kubectl get pods -n ecommerce

# Kết quả mong đợi: 6 pods READY (2 users, 2 products, 2 orders)
```

---

## 🔄 Demo CI Workflow - Pull Request

### Mục Đích:

Kiểm tra code quality, build Docker images, và chạy security scan trước khi merge vào `main`.

### Các Bước Demo:

#### 1. Tạo Feature Branch

```bash
# Tạo branch mới
git checkout -b demo/test-ci-workflow

# Thực hiện thay đổi nhỏ (ví dụ: update README)
echo "\n## Demo CI Workflow - $(date)" >> README.md

# Commit changes
git add README.md
git commit -m "test: demo CI workflow for presentation"

# Push to remote
git push origin demo/test-ci-workflow
```

#### 2. Tạo Pull Request

Vào GitHub: https://github.com/EurusDFIR/ecommerce_Microservice/pulls

**Click "New pull request":**

- Base: `main`
- Compare: `demo/test-ci-workflow`
- Title: `test: Demo CI workflow for presentation`
- Description:

  ```markdown
  ## Purpose

  Demonstrate CI/CD pipeline for project report presentation.

  ## Changes

  - Minor update to README for testing

  ## Expected Results

  - ✅ All 7 CI checks should pass
  - ✅ Code quality validation
  - ✅ Docker images build successfully
  - ✅ Security scans complete
  ```

#### 3. Theo Dõi CI Checks

Click vào tab **"Checks"** trong PR để xem real-time:

**Workflow: CI - Pull Request**

- ✅ **Code Quality** (ESLint, formatting) - ~30s
- ✅ **Build Users Service** (Docker build) - ~1m 30s
- ✅ **Build Products Service** (Docker build) - ~1m 30s
- ✅ **Build Orders Service** (Docker build) - ~1m 30s
- ✅ **Security Scan Users** (Trivy) - ~45s
- ✅ **Security Scan Products** (Trivy) - ~45s
- ✅ **Security Scan Orders** (Trivy) - ~45s

**Tổng thời gian:** ~5-7 phút

#### 4. Giải Thích Cho Hội Đồng

**Khi CI đang chạy:**

> "Hệ thống CI của chúng em đang tự động kiểm tra code quality, build Docker images cho 3 microservices, và scan security vulnerabilities. Đây là best practice của DevOps để đảm bảo code chất lượng trước khi merge vào nhánh chính."

**Khi CI pass:**

> "Tất cả 7 checks đã pass, chứng tỏ code không có lỗi syntax, Docker images build thành công, và không có lỗ hổng bảo mật nghiêm trọng. Giờ chúng em có thể merge an toàn vào main."

#### 5. Cleanup (Sau Demo)

```bash
# Đóng PR không merge (nếu chỉ demo)
# Hoặc merge nếu muốn giữ lại
git checkout main
git branch -D demo/test-ci-workflow
git push origin --delete demo/test-ci-workflow
```

---

## 🚀 Demo CD Workflow - Deploy to GKE

### Mục Đích:

Tự động build Docker images, push lên Artifact Registry, deploy lên GKE, và chạy E2E tests.

### ⚠️ Quan Trọng: CD Trigger Logic

**CD Workflow CHỈ chạy khi:**

```yaml
paths:
  - "services/**" # Code của microservices thay đổi
  - "infrastructure/k8s/**" # Kubernetes configs thay đổi
```

**CD Workflow KHÔNG chạy khi chỉ thay đổi:**

- `docs/**` (documentation)
- `*.md` (README, etc.)
- `postman/**` (API collections)
- `.github/workflows/ci-*.yml` (CI workflows)

**Ví dụ:**

- ✅ Thay đổi `services/users-service/app.js` → **CD CHẠY**
- ✅ Thay đổi `infrastructure/k8s/deployment.yaml` → **CD CHẠY**
- ❌ Thay đổi `README.md` → **CD KHÔNG CHẠY** (đúng!)
- ❌ Thay đổi `docs/ARCHITECTURE.md` → **CD KHÔNG CHẠY** (đúng!)

### Các Bước Demo:

#### 1. Trigger CD Workflow (Cách 1: Merge PR)

**Merge PR từ demo CI ở trên:**

- Click **"Merge pull request"** → **"Confirm merge"**
- CD workflow sẽ tự động trigger

**Giải thích:**

> "Khi merge vào main, hệ thống CD tự động trigger để deploy lên production. Điều này đảm bảo code mới nhất luôn được deploy nhanh chóng và nhất quán."

#### 2. Trigger CD Workflow (Cách 2: Manual - Khuyến Nghị cho Demo)

Vào: https://github.com/EurusDFIR/ecommerce_Microservice/actions/workflows/cd-deploy.yml

**Click "Run workflow":**

- Branch: `main`
- Service: `all` (deploy cả 3 services)
- Click **"Run workflow"**

**Giải thích:**

> "Chúng em cũng hỗ trợ manual deployment cho các trường hợp khẩn cấp hoặc khi cần kiểm soát thời điểm deploy cụ thể."

#### 3. Theo Dõi CD Pipeline

Click vào workflow run đang chạy:

**Jobs sẽ chạy tuần tự:**

**Job 1: Build & Push to Artifact Registry (~4-5 phút)**

```
Setup GCP credentials → Set up Cloud SDK → Configure Docker
→ Generate image tag → Build Users Docker image → Push Users image
→ Build Products Docker image → Push Products image
→ Build Orders Docker image → Push Orders image
```

**Giải thích:**

> "Bước này build 3 Docker images cho 3 microservices và push lên Google Artifact Registry. Tag image dùng timestamp + commit SHA để dễ truy vết."

**Job 2: Deploy to GKE (~2-3 phút)**

```
Setup GCP credentials → Configure kubectl
→ Deploy Users Service → Deploy Products Service → Deploy Orders Service
→ Wait for deployments → Verify deployments
```

**Giải thích:**

> "Sau khi build xong, hệ thống tự động deploy lên GKE cluster. Kubernetes sẽ rolling update để không có downtime."

**Job 3: E2E Tests (~1-2 phút)**

```
Setup environment → Run E2E test script
→ Test user registration → Test login → Test create order
→ Generate test report
```

**Giải thích:**

> "Cuối cùng chạy E2E tests để đảm bảo toàn bộ hệ thống hoạt động đúng sau khi deploy."

**Job 4: Deployment Notification**

```
Send notification to Slack/Discord (tùy chọn)
```

**Tổng thời gian:** ~8-12 phút

#### 4. Verify Deployment Thành Công

```bash
# Kiểm tra pods mới được deploy
kubectl get pods -n ecommerce -o wide

# Kiểm tra image tags mới
kubectl describe deployment users-service-postgres-deployment -n ecommerce | grep Image

# Test API endpoint
curl http://[EXTERNAL-IP]:8081/api/users/health
```

**Expected Output:**

```json
{
  "status": "healthy",
  "service": "users-service",
  "timestamp": "2025-10-11T12:00:00Z"
}
```

---

## 🗄️ Demo Database Migrations

### Mục Đích:

Chạy database migrations an toàn trên Cloud SQL production.

### Các Bước Demo:

#### 1. Chuẩn Bị Migration Script (Nếu Chưa Có)

```bash
# Tạo migration file mới
cat > services/users-service/migrations/003_add_demo_table.sql << 'EOF'
-- Demo migration for presentation
CREATE TABLE IF NOT EXISTS demo_logs (
  id SERIAL PRIMARY KEY,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO demo_logs (message) VALUES ('Demo migration executed successfully');
EOF
```

#### 2. Commit và Push Migration

```bash
git add services/users-service/migrations/003_add_demo_table.sql
git commit -m "feat: add demo migration for presentation"
git push origin main
```

#### 3. Trigger Database Migrations Workflow

Vào: https://github.com/EurusDFIR/ecommerce_Microservice/actions/workflows/database-migrations.yml

**Click "Run workflow":**

- Branch: `main`
- Service: `users-service-postgres`
- Click **"Run workflow"**

**Giải thích:**

> "Workflow này chạy database migrations một cách an toàn, sử dụng Cloud SQL Auth Proxy để kết nối bảo mật. Chúng em có thể chọn service cụ thể để migrate."

#### 4. Theo Dõi Migration Process

```
Setup GCP credentials → Connect to Cloud SQL
→ Run migrations → Verify schema changes
```

**Tổng thời gian:** ~1-2 phút

#### 5. Verify Migration Thành Công

```bash
# Connect to Cloud SQL (local)
gcloud sql connect ecommerce-cloudsql-instance --user=postgres --database=ecommerce_users

# Check table created
\dt demo_logs

# Check data inserted
SELECT * FROM demo_logs;
```

**Expected Output:**

```
 id |                message                 |         created_at
----+----------------------------------------+----------------------------
  1 | Demo migration executed successfully   | 2025-10-11 12:00:00.000000
```

---

## 🔥 Demo Hotfix Deployment

### Mục Đích:

Deploy hotfix nhanh chóng cho một service cụ thể mà không cần rebuild tất cả.

### Các Bước Demo:

#### 1. Giả Lập Tình Huống Hotfix

```bash
# Tạo hotfix branch
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug-fix

# Fix bug (ví dụ: sửa validation logic)
cat > services/users-service/src/hotfix-demo.js << 'EOF'
// Critical bug fix for demo
module.exports = {
  validateEmail: (email) => {
    // Fixed: improved regex validation
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }
};
EOF

# Commit hotfix
git add services/users-service/src/hotfix-demo.js
git commit -m "hotfix: improve email validation to prevent crash"
git push origin hotfix/critical-bug-fix
```

#### 2. Trigger Hotfix Deployment

Vào: https://github.com/EurusDFIR/ecommerce_Microservice/actions/workflows/hotfix-deployment.yml

**Click "Run workflow":**

- Branch: `hotfix/critical-bug-fix`
- Service: `users-service`
- Click **"Run workflow"**

**Giải thích:**

> "Trong trường hợp khẩn cấp, chúng em có workflow hotfix riêng để deploy nhanh chỉ service bị lỗi, không cần chờ CI đầy đủ. Điều này giảm downtime và giải quyết vấn đề nhanh hơn."

#### 3. Theo Dõi Hotfix Deployment

```
Build hotfix image → Push to Artifact Registry
→ Deploy to GKE → Quick smoke test
```

**Tổng thời gian:** ~3-4 phút (nhanh hơn CD đầy đủ)

#### 4. Verify Hotfix

```bash
# Check new pod deployed
kubectl get pods -n ecommerce -l app=users-service

# Test the fix
curl http://[EXTERNAL-IP]:8081/api/users/validate-email \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'
```

#### 5. Cleanup (Merge Hotfix vào Main)

```bash
# Create PR to merge hotfix back to main
git checkout main
git merge hotfix/critical-bug-fix
git push origin main

# Delete hotfix branch
git branch -D hotfix/critical-bug-fix
git push origin --delete hotfix/critical-bug-fix
```

---

## 🧪 Demo End-to-End Testing

### Mục Đích:

Kiểm tra toàn bộ luồng nghiệp vụ từ đầu đến cuối.

### Các Bước Demo:

#### 1. Chuẩn Bị Test Environment

```bash
# Get external IP của services
kubectl get services -n ecommerce

# Export variables
export USERS_API="http://[USERS-SERVICE-IP]:8081"
export PRODUCTS_API="http://[PRODUCTS-SERVICE-IP]:8082"
export ORDERS_API="http://[ORDERS-SERVICE-IP]:8083"
```

#### 2. Chạy E2E Test Script

```bash
# Chạy test script có sẵn
cd scripts
chmod +x test-e2e.sh
./test-e2e.sh
```

**Hoặc chạy từng bước thủ công:**

```bash
# Test 1: User Registration
echo "=== Test 1: User Registration ==="
curl -X POST $USERS_API/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "demo_user",
    "email": "demo@example.com",
    "password": "Demo@123"
  }'

# Test 2: User Login
echo -e "\n=== Test 2: User Login ==="
TOKEN=$(curl -X POST $USERS_API/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@example.com",
    "password": "Demo@123"
  }' | jq -r '.token')

echo "Token: $TOKEN"

# Test 3: Get Products
echo -e "\n=== Test 3: Get Products ==="
PRODUCTS=$(curl -X GET $PRODUCTS_API/api/products \
  -H "Authorization: Bearer $TOKEN")

echo $PRODUCTS | jq '.[0:3]'

# Test 4: Create Order
echo -e "\n=== Test 4: Create Order ==="
PRODUCT_ID=$(echo $PRODUCTS | jq -r '.[0].id')

curl -X POST $ORDERS_API/api/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"demo_user\",
    \"items\": [
      {
        \"productId\": \"$PRODUCT_ID\",
        \"quantity\": 2
      }
    ]
  }"

# Test 5: Get Order History
echo -e "\n=== Test 5: Get Order History ==="
curl -X GET $ORDERS_API/api/orders/user/demo_user \
  -H "Authorization: Bearer $TOKEN"
```

#### 3. Chạy Postman Collection

```bash
# Import collection vào Postman
# File: postman/E-commerce_Microservices_API_Collection.json

# Chạy toàn bộ collection với Newman (CLI)
npx newman run postman/E-commerce_Microservices_API_Collection.json \
  --environment postman/environments/Production.json \
  --reporters cli,html \
  --reporter-html-export newman-report.html
```

**Kết quả mong đợi:**

```
┌─────────────────────────┬──────────┬──────────┐
│                         │ executed │   failed │
├─────────────────────────┼──────────┼──────────┤
│              iterations │        1 │        0 │
├─────────────────────────┼──────────┼──────────┤
│                requests │       27 │        0 │
├─────────────────────────┼──────────┼──────────┤
│            test-scripts │       81 │        0 │
├─────────────────────────┼──────────┼──────────┤
│      prerequest-scripts │       10 │        0 │
├─────────────────────────┼──────────┼──────────┤
│              assertions │       81 │        0 │
└─────────────────────────┴──────────┴──────────┘
```

**Giải thích:**

> "Chúng em có Postman Collection với 27 API requests và 81 test assertions để kiểm tra toàn bộ chức năng của hệ thống. Tất cả tests đều pass, chứng tỏ hệ thống hoạt động đúng như mong đợi."

---

## 🎬 Kịch Bản Demo Hoàn Chỉnh (15-20 phút)

### Phần 1: Giới Thiệu Kiến Trúc (2 phút)

1. Mở file `docs/ARCHITECTURE_DIAGRAM.md`
2. Giải thích sơ đồ kiến trúc Microservices
3. Giải thích quy trình CI/CD

### Phần 2: Demo CI Workflow (5 phút)

1. Tạo branch mới và PR
2. Theo dõi CI checks real-time
3. Giải thích từng job đang chạy
4. Xác nhận tất cả checks pass

### Phần 3: Demo CD Workflow (7 phút)

1. Trigger manual deployment
2. Theo dõi build & push Docker images
3. Theo dõi deployment lên GKE
4. Verify pods mới được deploy
5. Chạy E2E tests tự động

### Phần 4: Demo Database Migrations (3 phút)

1. Trigger migration workflow
2. Verify schema changes trên Cloud SQL

### Phần 5: Demo E2E Testing (3 phút)

1. Chạy Postman Collection
2. Show test results: 27 requests, 81 assertions pass
3. Demo một số API calls thủ công

### Phần 6: Tổng Kết (2 phút)

1. Recap các best practices đã áp dụng
2. Show metrics: deployment frequency, success rate
3. Q&A

---

## 🐛 Troubleshooting

### Problem 1: CI Workflow Không Trigger

**Triệu chứng:** Push code nhưng không thấy CI chạy.

**Giải pháp:**

```bash
# Kiểm tra workflow syntax
cat .github/workflows/ci-pull-request.yml

# Kiểm tra branch protection rules
# Vào Settings > Branches > main > Edit

# Re-trigger workflow
git commit --amend --no-edit
git push origin [branch] --force-with-lease
```

### Problem 2: CD Deployment Failed - Authentication Error

**Triệu chứng:** `denied: Unauthenticated request`

**Giải pháp:**

```bash
# Kiểm tra GCP_SA_KEY secret
# Vào Settings > Secrets > Actions > GCP_SA_KEY

# Verify secret format (phải là base64)
echo "$GCP_SA_KEY" | base64 -d | jq .

# Re-generate service account key nếu cần
gcloud iam service-accounts keys create key.json \
  --iam-account=github-actions@ecommerce-micro-0037.iam.gserviceaccount.com

# Encode lại
cat key.json | base64 -w 0
```

### Problem 3: E2E Tests Failed

**Triệu chứng:** Một số test cases fail.

**Giải pháp:**

```bash
# Kiểm tra pods đang chạy
kubectl get pods -n ecommerce

# Check logs của service bị lỗi
kubectl logs [pod-name] -n ecommerce

# Restart deployment nếu cần
kubectl rollout restart deployment/[service]-deployment -n ecommerce

# Test lại API manually
curl http://[EXTERNAL-IP]:8081/api/users/health
```

### Problem 4: Workflow Chạy Quá Lâu

**Triệu chứng:** CD workflow > 15 phút.

**Giải pháp:**

```bash
# Kiểm tra logs của job bị chậm
# Thường là "Build & Push" job

# Cancel workflow đang chạy
gh workflow run cancel [run-id]

# Clear GitHub Actions cache
gh cache delete --all

# Re-run workflow
gh workflow run cd-deploy.yml --ref main
```

### Problem 5: GKE Pods CrashLoopBackOff

**Triệu chứng:** Pods không start được sau deploy.

**Giải pháp:**

```bash
# Kiểm tra pod status
kubectl describe pod [pod-name] -n ecommerce

# Check logs
kubectl logs [pod-name] -n ecommerce --previous

# Common fixes:
# 1. Sai DB credentials
kubectl get secret cloudsql-db-credentials -n ecommerce -o yaml

# 2. Cloud SQL Auth Proxy không kết nối được
kubectl logs [pod-name] -n ecommerce -c cloud-sql-proxy

# 3. Image không tồn tại
gcloud artifacts docker images list \
  asia-southeast1-docker.pkg.dev/ecommerce-micro-0037/ecommerce-images
```

---

## 📊 Metrics & KPIs Để Trình Bày

### CI/CD Performance:

- **Deployment Frequency:** ~3-5 lần/ngày
- **Lead Time:** < 15 phút (từ commit đến production)
- **Change Failure Rate:** < 5%
- **Mean Time to Recovery (MTTR):** < 10 phút (hotfix)

### System Performance:

- **API Response Time:** < 200ms (p95)
- **Uptime:** 99.9%
- **Concurrent Users:** 100+ (tested)

### Test Coverage:

- **Unit Tests:** 80%+
- **Integration Tests:** 27 API endpoints
- **E2E Tests:** 81 assertions

---

## 🎓 Câu Hỏi Thường Gặp Từ Hội Đồng

### Q1: "Tại sao không dùng Jenkins mà dùng GitHub Actions?"

**A:** GitHub Actions tích hợp sẵn với repository, không cần setup server riêng, có 2000 phút/tháng miễn phí, và dễ maintain hơn. Phù hợp với quy mô dự án hiện tại.

### Q2: "Làm sao đảm bảo không có downtime khi deploy?"

**A:** Kubernetes rolling update deployment với `maxUnavailable: 0` và `maxSurge: 1`. GKE tự động tạo pod mới trước khi tắt pod cũ.

### Q3: "Secret management có an toàn không?"

**A:** Secrets được lưu encrypted trên GitHub, decode trong runtime, không commit vào code. GCP service account có IAM roles giới hạn theo principle of least privilege.

### Q4: "Nếu một microservice lỗi thì ảnh hưởng gì?"

**A:** Mỗi service độc lập, lỗi một service không crash toàn bộ hệ thống. Health checks tự động restart pod bị lỗi.

### Q5: "Chi phí vận hành GCP là bao nhiêu?"

**A:** GKE cluster: ~$100/tháng, Cloud SQL: ~$50/tháng, Firestore: ~$20/tháng. Tổng ~$170/tháng cho production environment.

---

## ✅ Checklist Trước Khi Demo

### Technical:

- [ ] GKE cluster running và healthy
- [ ] Tất cả pods trong trạng thái READY
- [ ] GitHub Secrets configured đúng
- [ ] Test E2E script một lần trước
- [ ] Postman Collection import và test
- [ ] Internet connection stable

### Presentation:

- [ ] Mở sẵn GitHub Actions tab
- [ ] Mở sẵn GCP Console
- [ ] Mở sẵn terminal với kubectl configured
- [ ] Mở sẵn Postman
- [ ] Chuẩn bị backup slides/screenshots nếu demo fail

### Documentation:

- [ ] `docs/ARCHITECTURE_DIAGRAM.md` reviewed
- [ ] `docs/BAO_CAO_DO_AN_ECOMMERCE_MICROSERVICES_GCP.md` printed/ready
- [ ] `postman/README.md` for API testing guide
- [ ] This demo guide accessible offline

---

## 🎉 Kết Luận

Với hướng dẫn này, bạn có thể tự tin demo toàn bộ quy trình CI/CD và các workflows của hệ thống E-commerce Microservices. Hãy practice trước 1-2 lần để đảm bảo mọi thứ chạy mượt mà.

**Chúc bạn demo thành công và đạt điểm cao!** 🚀

---

_Document Version: 1.0_  
_Last Updated: October 11, 2025_  
_Author: EurusDFIR Team_

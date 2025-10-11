# Quick Reference: CD Workflow Trigger

## 🎯 Khi Nào CD Workflow Chạy?

### ✅ CD SẼ CHẠY khi merge PR với thay đổi:

```bash
# Thay đổi code services
services/users-service/**
services/products-service/**
services/orders-service/**

# Thay đổi Kubernetes configs
infrastructure/k8s/**
```

### ❌ CD KHÔNG CHẠY khi chỉ thay đổi:

```bash
# Documentation
docs/**
README.md
*.md

# Testing files
postman/**
scripts/**

# CI workflows
.github/workflows/ci-*.yml
.github/workflows/database-migrations.yml
```

---

## 🚀 Để Demo CD Workflow:

### Cách 1: Thay Đổi Service Code (Khuyến Nghị)

```bash
# Tạo branch demo
git checkout -b demo/trigger-cd

# Thêm comment nhỏ vào service
echo "// Demo CD trigger" >> services/users-service/app-postgres.js

# Commit & push
git add .
git commit -m "feat: trigger CD for demo"
git push origin demo/trigger-cd

# Tạo PR → Merge → CD sẽ CHẠY! ✅
```

### Cách 2: Manual Trigger

```bash
# Vào GitHub Actions:
https://github.com/EurusDFIR/ecommerce_Microservice/actions/workflows/cd-deploy.yml

# Click "Run workflow"
# Branch: main
# Service: all
# → CD sẽ CHẠY ngay! ✅
```

---

## 📊 So Sánh Trigger Logic:

| **Thay Đổi** | **CI Trigger?** | **CD Trigger?** |
|---|---|---|
| `services/users-service/app.js` | ✅ Yes (PR) | ✅ Yes (merge) |
| `infrastructure/k8s/deployment.yaml` | ✅ Yes (PR) | ✅ Yes (merge) |
| `README.md` | ✅ Yes (PR) | ❌ **NO** |
| `docs/ARCHITECTURE.md` | ✅ Yes (PR) | ❌ **NO** |
| `postman/collection.json` | ✅ Yes (PR) | ❌ **NO** |

**Tóm tắt:**
- **CI:** Luôn chạy trên mọi PR (kiểm tra code quality)
- **CD:** Chỉ chạy khi code services/infrastructure thay đổi (deploy có chủ đích)

---

## 🎬 Kịch Bản Demo Thực Tế:

### Demo 1: Update Docs (CI Only)
```bash
# Thay đổi README
echo "Update" >> README.md
git commit -am "docs: update README"
git push

# Kết quả:
# ✅ CI chạy (code quality check)
# ❌ CD KHÔNG chạy (không cần deploy)
# → Tiết kiệm thời gian & chi phí! 💰
```

### Demo 2: Update Service (CI + CD)
```bash
# Thay đổi service code
echo "// Fix bug" >> services/users-service/app-postgres.js
git commit -am "fix: critical bug"
git push

# Kết quả:
# ✅ CI chạy (code quality check)
# ✅ CD CHẠY (auto deploy to GKE)
# → Hệ thống tự động cập nhật! 🚀
```

---

## 🐛 Troubleshooting:

### "Tôi merge PR nhưng CD không chạy!"

**Nguyên nhân:** PR chỉ thay đổi docs/README, không match `paths` filter.

**Giải pháp:** Đây là **ĐÚNG**! CD không nên chạy khi chỉ docs thay đổi.

**Nếu muốn trigger CD:**
1. Thêm một comment nhỏ vào service code
2. Hoặc dùng manual trigger: `workflow_dispatch`

### "Workflow bị lỗi 'Invalid workflow file'"

**Nguyên nhân:** Dùng cả `paths` VÀ `paths-ignore` cùng lúc.

**Giải pháp:** Chỉ dùng `paths` (GitHub Actions không cho phép cả hai).

```yaml
# ❌ SAI
on:
  push:
    paths: [...]
    paths-ignore: [...]  # Conflict!

# ✅ ĐÚNG
on:
  push:
    paths:
      - "services/**"
      - "infrastructure/k8s/**"
```

---

## 📚 Tài Liệu Liên Quan:

- Full Demo Guide: `docs/HUONG_DAN_DEMO_WORKFLOWS.md`
- Architecture: `docs/ARCHITECTURE_DIAGRAM.md`
- Project Report: `docs/BAO_CAO_DO_AN_ECOMMERCE_MICROSERVICES_GCP.md`

---

*Last Updated: October 11, 2025*

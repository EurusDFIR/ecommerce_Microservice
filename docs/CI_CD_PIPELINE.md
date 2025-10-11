# CI/CD Pipeline Documentation

## Overview

This project uses **GitHub Actions** for continuous integration and continuous deployment (CI/CD) to automate testing, building, and deploying microservices to Google Kubernetes Engine (GKE).

## Workflows

### 1. 🧪 CI - Pull Request (`ci-pull-request.yml`)

**Trigger:** Pull requests to `main` or `develop` branches

**Purpose:** Validate code changes before merging

**Jobs:**

1. **Code Quality** - Run linters and formatting checks
2. **Build Images** - Build Docker images for all services
3. **Security Scan** - Run Trivy vulnerability scanner
4. **Validate Migrations** - Test database migrations against local PostgreSQL
5. **PR Summary** - Generate comprehensive summary

**Duration:** ~5-8 minutes

---

### 2. 🚀 CD - Deploy to GKE (`cd-deploy.yml`)

**Trigger:**

- Push to `main` branch
- Manual workflow dispatch

**Purpose:** Automated deployment to production GKE cluster

**Jobs:**

1. **Build & Push** - Build Docker images and push to Artifact Registry
   - Generates unique tags: `YYYYMMDD-HHMMSS-<short-sha>`
   - Tags as `latest` for convenience
2. **Deploy to GKE** - Update Kubernetes deployments
   - Uses `kubectl set image` for zero-downtime rolling updates
   - Waits for rollout completion (5-minute timeout)
3. **Post-Deployment Tests** - Run E2E test suite
   - Validates all services are working
   - Tests database connectivity
4. **Notify** - Send deployment summary

**Duration:** ~10-15 minutes

**Manual Deployment:**

```bash
# From GitHub UI: Actions > CD - Deploy to GKE > Run workflow
# Select service: all, users, products, or orders
```

---

### 3. 🗄️ Database Migrations (`database-migrations.yml`)

**Trigger:** Manual workflow dispatch only

**Purpose:** Safely apply database schema changes

**Features:**

- **Dry Run Mode** - Preview changes without applying
- **Automatic Backup** - Creates Cloud SQL backup before migration
- **Post-Validation** - Restarts services and runs E2E tests
- **Rollback Support** - Can restore from backup if needed

**Jobs:**

1. **Backup Databases** - Create Cloud SQL backups
2. **Run Migrations** - Execute SQL migration scripts via Cloud SQL Proxy
3. **Validate Migration** - Restart services and run tests
4. **Migration Summary** - Generate detailed report

**Usage:**

```bash
# Dry run (preview only):
Actions > Database Migrations > Run workflow
- Migration type: all / users-schema / products-schema
- Dry run: ✅ true

# Production migration:
Actions > Database Migrations > Run workflow
- Migration type: all
- Dry run: ❌ false
```

**Duration:**

- Dry run: ~3-5 minutes
- Production: ~8-12 minutes (includes backup)

---

### 4. 🔥 Hotfix Deployment (`hotfix-deployment.yml`)

**Trigger:** Manual workflow dispatch only

**Purpose:** Emergency deployment of specific image version

**Features:**

- Deploy specific image tag to production
- Automatic backup of current deployment
- Health checks after deployment
- Automatic rollback on failure
- Reason tracking for audit

**Jobs:**

1. **Validate** - Verify image exists in Artifact Registry
2. **Backup Deployment** - Save current deployment config
3. **Deploy Hotfix** - Apply new image tag
4. **Health Check** - Run E2E tests
5. **Rollback** - Auto-rollback if health checks fail
6. **Notify** - Send hotfix summary

**Usage:**

```bash
Actions > Hotfix Deployment > Run workflow
- Service: users-service / products-service / orders-service
- Image tag: v2.4-postgres (or any existing tag)
- Reason: "Fix critical auth bug in production"
```

**Duration:** ~8-10 minutes

---

## Setup Instructions

### 1. Configure GitHub Secrets

Navigate to: **Settings > Secrets and variables > Actions > New repository secret**

Required secrets:

```bash
# GCP Service Account Key (JSON)
GCP_SA_KEY=<base64-encoded-service-account-json>

# Database Password
DB_PASSWORD=<postgres-password>

# Optional: Notification webhooks
SLACK_WEBHOOK_URL=<slack-webhook>
```

**Generate GCP_SA_KEY:**

```bash
# Create service account with required roles:
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions SA"

# Grant roles:
gcloud projects add-iam-policy-binding ecommerce-micro-0037 \
  --member="serviceAccount:github-actions-sa@ecommerce-micro-0037.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding ecommerce-micro-0037 \
  --member="serviceAccount:github-actions-sa@ecommerce-micro-0037.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding ecommerce-micro-0037 \
  --member="serviceAccount:github-actions-sa@ecommerce-micro-0037.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# Create and download key:
gcloud iam service-accounts keys create ~/github-actions-key.json \
  --iam-account=github-actions-sa@ecommerce-micro-0037.iam.gserviceaccount.com

# Base64 encode (for GitHub secret):
cat ~/github-actions-key.json | base64 -w 0
```

---

### 2. Enable GitHub Actions

1. Go to **Settings > Actions > General**
2. Under "Actions permissions", select: **Allow all actions and reusable workflows**
3. Under "Workflow permissions", select: **Read and write permissions**
4. Check: **✅ Allow GitHub Actions to create and approve pull requests**

---

### 3. Configure Branch Protection

**Settings > Branches > Add rule**

For `main` branch:

- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging
  - Select: `Code Quality`, `Build Docker Images`, `Security Scan`, `Validate Migrations`
- ✅ Require branches to be up to date before merging
- ✅ Require conversation resolution before merging

---

## Workflow Triggers

| Workflow            | Trigger            | Frequency          | Manual         |
| ------------------- | ------------------ | ------------------ | -------------- |
| CI - Pull Request   | PR to main/develop | On every PR commit | ❌             |
| CD - Deploy to GKE  | Push to main       | On merge           | ✅ Yes         |
| Database Migrations | -                  | Never automatic    | ✅ Manual only |
| Hotfix Deployment   | -                  | Never automatic    | ✅ Manual only |

---

## CI/CD Pipeline Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   Developer Workflow                         │
└─────────────────────────────────────────────────────────────┘

1️⃣  Developer creates feature branch
    ├─ git checkout -b feature/new-auth-endpoint
    └─ Make code changes

2️⃣  Developer pushes and creates PR
    ├─ git push origin feature/new-auth-endpoint
    └─ Create Pull Request on GitHub
        ↓
    🧪 CI - Pull Request Workflow Triggered
        ├─ ✅ Code quality checks
        ├─ ✅ Build Docker images
        ├─ ✅ Security scanning
        ├─ ✅ Validate migrations
        └─ ✅ PR Summary generated

3️⃣  Code review and approval
    ├─ Team reviews code
    ├─ All CI checks pass
    └─ PR approved and merged to main
        ↓
    🚀 CD - Deploy to GKE Workflow Triggered
        ├─ 📦 Build images (tag: YYYYMMDD-HHMMSS-<sha>)
        ├─ 📤 Push to Artifact Registry
        ├─ ☸️  Deploy to GKE (rolling update)
        ├─ 🏥 Run E2E tests
        └─ ✅ Deployment complete

4️⃣  Database changes (if needed)
    └─ Manual trigger: Database Migrations Workflow
        ├─ 💾 Create Cloud SQL backup
        ├─ 🗄️  Run migration scripts
        ├─ 🔄 Restart services
        └─ ✅ Validate with E2E tests

5️⃣  Emergency hotfix (if needed)
    └─ Manual trigger: Hotfix Deployment Workflow
        ├─ 📦 Backup current deployment
        ├─ 🔥 Deploy specific image tag
        ├─ 🏥 Run health checks
        └─ ✅ Success (or 🔄 auto-rollback)
```

---

## Best Practices

### Development Workflow

1. **Always create feature branches**

   ```bash
   git checkout -b feature/add-payment-service
   ```

2. **Keep PRs small and focused**

   - Single feature or bug fix per PR
   - Easier to review and test

3. **Write descriptive commit messages**

   ```bash
   git commit -m "feat(users): Add password reset endpoint"
   git commit -m "fix(orders): Handle null cart items gracefully"
   ```

4. **Wait for CI checks before requesting review**
   - All checks should pass ✅
   - Fix any linting or test failures

---

### Deployment Strategy

1. **Always test in staging first** (if available)
2. **Use dry-run for database migrations**

   ```bash
   # Preview changes first
   Workflow: Database Migrations
   Dry run: ✅ true

   # Then apply
   Dry run: ❌ false
   ```

3. **Monitor deployments**

   ```bash
   # Watch rollout status
   kubectl rollout status deployment/users-service-postgres-deployment -n ecommerce

   # Check logs
   kubectl logs -f deployment/users-service-postgres-deployment -n ecommerce
   ```

4. **Use hotfix workflow for emergencies only**
   - Document reason clearly
   - Follow up with proper PR

---

### Rollback Procedures

**Option 1: Using Kubernetes Rollback**

```bash
# Rollback to previous version
kubectl rollout undo deployment/users-service-postgres-deployment -n ecommerce

# Rollback to specific revision
kubectl rollout history deployment/users-service-postgres-deployment -n ecommerce
kubectl rollout undo deployment/users-service-postgres-deployment -n ecommerce --to-revision=3
```

**Option 2: Using Hotfix Workflow**

```bash
# Deploy previous known-good image
Actions > Hotfix Deployment > Run workflow
Service: users-service
Image tag: v2.3-postgres  # Previous version
Reason: "Rollback due to bug in v2.4"
```

**Option 3: Database Rollback**

```bash
# List backups
gcloud sql backups list --instance=ecommerce-postgres

# Restore from backup
gcloud sql backups restore BACKUP_ID --backup-instance=ecommerce-postgres
```

---

## Monitoring & Debugging

### View Workflow Runs

1. Go to **Actions** tab in GitHub
2. Click on workflow name
3. Click on specific run
4. View logs for each job

### Common Issues

**Issue: `GCP_SA_KEY` secret invalid**

```bash
# Solution: Verify base64 encoding
cat ~/github-actions-key.json | base64 -w 0 | wc -c
# Should be > 1000 characters
```

**Issue: Docker build fails - insufficient memory**

```bash
# Solution: Use multi-stage builds (already implemented)
# Or increase GitHub Actions runner resources
```

**Issue: Deployment timeout**

```bash
# Solution: Check pod status
kubectl get pods -n ecommerce
kubectl describe pod <pod-name> -n ecommerce
kubectl logs <pod-name> -n ecommerce
```

**Issue: E2E tests fail after deployment**

```bash
# Check service connectivity
kubectl get svc -n ecommerce
kubectl port-forward svc/users-service 8001:80 -n ecommerce

# Test manually
curl http://localhost:8001/health
```

---

## Metrics & KPIs

Track these metrics to measure CI/CD effectiveness:

- **Deployment Frequency**: How often code is deployed
- **Lead Time**: Time from commit to production
- **Mean Time to Recovery (MTTR)**: Time to recover from failure
- **Change Failure Rate**: % of deployments causing failures

**View in GitHub:**

- Actions > Workflows > View workflow runs
- Insights > Dependency graph > Dependencies

---

## Future Enhancements

- [ ] Add Slack/Discord notifications
- [ ] Implement staging environment
- [ ] Add performance testing stage
- [ ] Integrate SonarQube for code quality
- [ ] Add canary deployments
- [ ] Implement blue-green deployments
- [ ] Add automated rollback on error rate increase
- [ ] Integrate with monitoring (Prometheus/Grafana)

---

## Support

For issues or questions:

1. Check workflow logs in GitHub Actions
2. Review this documentation
3. Check GKE pod logs: `kubectl logs -f <pod-name> -n ecommerce`
4. Contact DevOps team

---

**Last Updated:** 2024-01-10  
**Maintained by:** DevOps Team

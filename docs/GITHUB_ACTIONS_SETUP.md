# GitHub Actions Setup Guide

This guide will walk you through setting up GitHub Actions for automated CI/CD pipelines.

## Prerequisites

- GitHub repository for this project
- GCP project with:
  - GKE cluster running
  - Cloud SQL PostgreSQL instance
  - Firestore database
  - Artifact Registry repository
- `gcloud` CLI installed locally

---

## Step 1: Create GitHub Repository

If you haven't already:

```bash
# Initialize git (if not already done)
cd /r/_Projects/Eurus_Workspace/e_commerce_microservice
git init

# Add remote
git remote add origin https://github.com/YOUR_USERNAME/e-commerce-microservice.git

# Initial commit
git add .
git commit -m "Initial commit: E-commerce microservices with CI/CD"
git branch -M main
git push -u origin main
```

---

## Step 2: Create GCP Service Account for GitHub Actions

```bash
# Set project ID
export PROJECT_ID=ecommerce-micro-0037

# Create service account
gcloud iam service-accounts create github-actions-sa \
  --display-name="GitHub Actions Service Account" \
  --description="Service account for GitHub Actions CI/CD" \
  --project=$PROJECT_ID

# Get service account email
export SA_EMAIL=github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/container.developer" \
  --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.writer" \
  --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/cloudsql.client" \
  --condition=None

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser" \
  --condition=None

# Create and download key
gcloud iam service-accounts keys create ~/github-actions-key.json \
  --iam-account=${SA_EMAIL} \
  --project=$PROJECT_ID

echo "✅ Service account created: ${SA_EMAIL}"
echo "✅ Key saved to: ~/github-actions-key.json"
```

---

## Step 3: Configure GitHub Secrets

### 3.1 Prepare GCP Service Account Key

```bash
# Base64 encode the key (for GitHub secret)
cat ~/github-actions-key.json | base64 -w 0 > ~/github-actions-key-base64.txt

# Copy to clipboard (Linux)
cat ~/github-actions-key-base64.txt | xclip -selection clipboard

# Or display and copy manually
cat ~/github-actions-key-base64.txt
```

### 3.2 Add Secrets to GitHub

1. Go to your GitHub repository
2. Navigate to: **Settings > Secrets and variables > Actions**
3. Click **New repository secret**

Add the following secrets:

| Secret Name      | Value                            | Description                                       |
| ---------------- | -------------------------------- | ------------------------------------------------- |
| `GCP_SA_KEY`     | _Base64 encoded JSON from above_ | GCP Service Account credentials                   |
| `DB_PASSWORD`    | Your PostgreSQL password         | Cloud SQL database password                       |
| `GCP_PROJECT_ID` | `ecommerce-micro-0037`           | GCP Project ID (optional, hardcoded in workflows) |

**Screenshots:**

```
Settings > Secrets and variables > Actions > New repository secret

┌─────────────────────────────────────────┐
│ Name: GCP_SA_KEY                        │
│                                         │
│ Secret: ewogICJ0eXBlIjogInNlcnZpY2... │
│                                         │
│         [Add secret]                    │
└─────────────────────────────────────────┘
```

---

## Step 4: Enable GitHub Actions

### 4.1 Configure Actions Permissions

1. Go to: **Settings > Actions > General**
2. Under **Actions permissions**:
   - Select: ✅ **Allow all actions and reusable workflows**
3. Under **Workflow permissions**:
   - Select: ✅ **Read and write permissions**
   - Check: ✅ **Allow GitHub Actions to create and approve pull requests**
4. Click **Save**

### 4.2 Verify Workflow Files

Ensure these files exist:

```bash
.github/workflows/
├── ci-pull-request.yml      # ✅ Created
├── cd-deploy.yml             # ✅ Created
├── database-migrations.yml   # ✅ Created
└── hotfix-deployment.yml     # ✅ Created
```

---

## Step 5: Configure Branch Protection Rules

### 5.1 Protect Main Branch

1. Go to: **Settings > Branches**
2. Click **Add rule** or edit existing rule for `main`

**Branch name pattern:** `main`

**Configure rules:**

- ✅ **Require a pull request before merging**
  - Require approvals: `1` (minimum)
  - ✅ Dismiss stale pull request approvals when new commits are pushed
- ✅ **Require status checks to pass before merging**
  - ✅ Require branches to be up to date before merging
  - **Status checks that are required:**
    - `Code Quality`
    - `Build Docker Images`
    - `Security Scan`
    - `Validate Migrations`
- ✅ **Require conversation resolution before merging**

- ✅ **Do not allow bypassing the above settings**

3. Click **Create** or **Save changes**

---

## Step 6: Test CI/CD Pipeline

### 6.1 Test PR Workflow

```bash
# Create feature branch
git checkout -b feature/test-ci-cd

# Make a small change
echo "# CI/CD Test" >> README.md

# Commit and push
git add README.md
git commit -m "test: Verify CI/CD pipeline"
git push origin feature/test-ci-cd
```

**On GitHub:**

1. Create Pull Request from `feature/test-ci-cd` to `main`
2. Watch Actions tab - CI workflow should trigger
3. Verify all checks pass ✅
4. Merge PR (if all checks pass)

### 6.2 Test CD Workflow

After merging PR:

1. Go to **Actions** tab
2. Select **CD - Deploy to GKE**
3. Verify workflow runs automatically
4. Check all jobs complete successfully

### 6.3 Test Manual Workflows

**Test Database Migration (Dry Run):**

1. Go to: **Actions > Database Migrations > Run workflow**
2. Select:
   - Branch: `main`
   - Migration type: `all`
   - Dry run: `✅ true`
3. Click **Run workflow**
4. Monitor execution

**Test Hotfix Deployment:**

1. Go to: **Actions > Hotfix Deployment > Run workflow**
2. Select:
   - Branch: `main`
   - Service: `users-service`
   - Image tag: `latest`
   - Reason: `Testing hotfix workflow`
3. Click **Run workflow**
4. Monitor execution

---

## Step 7: Verify Deployment

### 7.1 Check GKE Cluster

```bash
# Get GKE credentials
gcloud container clusters get-credentials my-ecommerce-cluster \
  --region=asia-southeast1 \
  --project=ecommerce-micro-0037

# Check deployments
kubectl get deployments -n ecommerce

# Expected output:
# NAME                                  READY   UP-TO-DATE   AVAILABLE
# users-service-postgres-deployment     2/2     2            2
# products-service-postgres-deployment  2/2     2            2
# orders-service-firestore-deployment   2/2     2            2

# Check pods
kubectl get pods -n ecommerce

# Check services
kubectl get services -n ecommerce
```

### 7.2 Run E2E Tests

```bash
# From local machine
cd /r/_Projects/Eurus_Workspace/e_commerce_microservice
chmod +x scripts/test-e2e.sh
./scripts/test-e2e.sh

# Expected: All 7/7 tests should pass ✅
```

---

## Step 8: Monitor Workflows

### View Workflow Status

**GitHub UI:**

1. Go to **Actions** tab
2. View recent workflow runs
3. Click on a run to see details
4. Click on a job to see logs

**Workflow Badges (Optional):**

Add to README.md:

```markdown
![CI](https://github.com/YOUR_USERNAME/e-commerce-microservice/actions/workflows/ci-pull-request.yml/badge.svg)
![CD](https://github.com/YOUR_USERNAME/e-commerce-microservice/actions/workflows/cd-deploy.yml/badge.svg)
```

---

## Troubleshooting

### Issue: "Secret GCP_SA_KEY not found"

**Solution:**

```bash
# Verify secret is added correctly
# Go to: Settings > Secrets and variables > Actions
# Ensure GCP_SA_KEY is listed

# Re-create if needed:
cat ~/github-actions-key.json | base64 -w 0
# Copy output and update secret in GitHub
```

### Issue: "Permission denied: gcloud auth"

**Solution:**

```bash
# Verify service account has correct roles
gcloud projects get-iam-policy ecommerce-micro-0037 \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-sa*" \
  --format="table(bindings.role)"

# Should show:
# roles/artifactregistry.writer
# roles/cloudsql.client
# roles/container.developer
# roles/iam.serviceAccountUser
```

### Issue: "Workflow does not run on PR"

**Solution:**

1. Check workflow file syntax (YAML indentation)
2. Verify workflow is in `.github/workflows/` directory
3. Ensure Actions are enabled: Settings > Actions > General
4. Check workflow triggers in `.yml` file

### Issue: "Docker build fails in workflow"

**Solution:**

```yaml
# Verify Dockerfile paths in workflow:
- services/users-service/Dockerfile.postgres     ✅
- services/products-service/Dockerfile.postgres  ✅
- services/orders-service/Dockerfile.firestore   ✅

# Check build context is correct
context: ./services/users-service
```

### Issue: "kubectl command not found"

**Solution:**

```yaml
# Workflow should install gke-gcloud-auth-plugin:
- name: Install gke-gcloud-auth-plugin
  run: |
    gcloud components install gke-gcloud-auth-plugin --quiet
```

### Issue: "E2E tests fail in workflow"

**Solution:**

```bash
# Check if pods are ready:
kubectl get pods -n ecommerce

# Check service connectivity:
kubectl get services -n ecommerce

# View pod logs:
kubectl logs -f deployment/users-service-postgres-deployment -n ecommerce

# Verify database connections:
kubectl exec -it deployment/users-service-postgres-deployment -n ecommerce -- \
  env | grep DB_
```

---

## Security Best Practices

### 1. Rotate Service Account Keys Regularly

```bash
# Create new key
gcloud iam service-accounts keys create ~/github-actions-key-new.json \
  --iam-account=github-actions-sa@ecommerce-micro-0037.iam.gserviceaccount.com

# Update GitHub secret with new key
cat ~/github-actions-key-new.json | base64 -w 0

# Delete old key (after verifying new one works)
gcloud iam service-accounts keys list \
  --iam-account=github-actions-sa@ecommerce-micro-0037.iam.gserviceaccount.com

gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=github-actions-sa@ecommerce-micro-0037.iam.gserviceaccount.com
```

### 2. Use Least Privilege Principle

```bash
# Review and minimize permissions
gcloud projects get-iam-policy ecommerce-micro-0037 \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-sa*"

# Remove unnecessary roles if any
```

### 3. Enable Audit Logging

```bash
# View GitHub Actions audit log
# Settings > Logs > Audit log
```

---

## Next Steps

After setting up CI/CD:

1. ✅ Test all workflows
2. ✅ Configure Slack/Discord notifications (optional)
3. ✅ Set up staging environment (optional)
4. ✅ Move to **Priority #3: Ingress Controller**

---

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Google Cloud GitHub Actions](https://github.com/google-github-actions)
- [GKE Deployment Best Practices](https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-workloads-overview)
- [Our CI/CD Documentation](./CI_CD_PIPELINE.md)

---

**Created:** 2024-01-10  
**Status:** ✅ Ready for Production

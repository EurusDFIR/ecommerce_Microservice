# Troubleshooting: GCP Authentication in GitHub Actions

## 🔴 Common Error: "You do not currently have an active account selected"

### Error Message:

```
ERROR: (gcloud.container.clusters.get-credentials)
You do not currently have an active account selected.
Please run:
  $ gcloud auth login
```

---

## 🎯 Root Cause

**WRONG ORDER** of operations:

```yaml
# ❌ WRONG - Activating before SDK is ready
- name: Activate service account
  run: gcloud auth activate-service-account --key-file=...

- name: Setup Cloud SDK
  uses: google-github-actions/setup-gcloud@v2
# Result: SDK installation overrides authentication!
```

**The Problem:**

1. You activate service account first
2. Then setup-gcloud action installs/updates SDK
3. SDK reset clears your authentication
4. Later gcloud commands fail with "no active account"

---

## ✅ Solution: Correct Order

### Step 1: Decode Credentials (if base64-encoded)

```yaml
- name: Decode and setup GCP credentials
  run: |
    echo "${{ secrets.GCP_SA_KEY }}" | base64 -d > ${HOME}/gcp-key.json

    # Validate JSON
    if ! cat ${HOME}/gcp-key.json | jq empty 2>/dev/null; then
      echo "Error: Invalid JSON"
      exit 1
    fi

    # Set environment variable
    echo "GOOGLE_APPLICATION_CREDENTIALS=${HOME}/gcp-key.json" >> $GITHUB_ENV
```

### Step 2: Setup Cloud SDK FIRST

```yaml
- name: Set up Cloud SDK
  uses: google-github-actions/setup-gcloud@v2
  with:
    project_id: ${{ env.GCP_PROJECT_ID }}
```

### Step 3: Activate Service Account AFTER SDK is ready

```yaml
- name: Authenticate with service account
  run: |
    # Activate service account (this automatically sets it as active!)
    gcloud auth activate-service-account --key-file=${HOME}/gcp-key.json
    
    # Set project explicitly
    gcloud config set project ${{ env.GCP_PROJECT_ID }}
    
    # Optional: Verify immediately
    echo "Active account: $(gcloud config get-value account)"
    echo "Project: $(gcloud config get-value project)"
```

**Important:** `gcloud auth activate-service-account` **automatically** sets the account as active. You don't need to manually extract email and set account!

### Step 4: Verify Authentication

```yaml
- name: Verify authentication
  run: |
    gcloud auth list
    gcloud config get-value project
```

---

## 🔍 Complete Working Example

```yaml
deploy-to-gke:
  name: Deploy to GKE
  runs-on: ubuntu-latest

  steps:
    - name: Checkout code
      uses: actions/checkout@v4

    # Step 1: Decode credentials (if base64)
    - name: Decode and setup GCP credentials
      run: |
        echo "${{ secrets.GCP_SA_KEY }}" | base64 -d > ${HOME}/gcp-key.json
        echo "GOOGLE_APPLICATION_CREDENTIALS=${HOME}/gcp-key.json" >> $GITHUB_ENV

    # Step 2: Setup SDK first
    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v2
      with:
        project_id: ${{ env.GCP_PROJECT_ID }}

    # Step 3: Activate service account after SDK is ready
    - name: Authenticate with service account
      run: |
        gcloud auth activate-service-account --key-file=${HOME}/gcp-key.json
        gcloud config set project ${{ env.GCP_PROJECT_ID }}

    # Step 4: Verify
    - name: Verify authentication
      run: |
        echo "✅ Authenticated as:"
        gcloud auth list
        echo "✅ Current project:"
        gcloud config get-value project

    # Now you can use gcloud commands safely!
    - name: Get GKE credentials
      run: |
        gcloud container clusters get-credentials my-cluster \
          --region=us-central1 \
          --project=${{ env.GCP_PROJECT_ID }}
```

---

## 🧪 How to Test

### Test 1: Verify Authentication

```bash
# After "Authenticate with service account" step
gcloud auth list
# Should show: ACTIVE account email

gcloud config get-value project
# Should show: your-project-id
```

### Test 2: Test GKE Access

```bash
# This should work without errors
gcloud container clusters list
gcloud container clusters get-credentials your-cluster \
  --region=your-region
```

### Test 3: Test kubectl

```bash
kubectl get nodes
kubectl get namespaces
# Should list resources successfully
```

---

## 🐛 Other Common Issues

### Issue 1: "jq: command not found" or "python parsing error"
**Cause:** Trying to extract service account email from JSON file

**Wrong approach:**
```bash
# ❌ Don't do this - jq not available in runner
ACCOUNT_EMAIL=$(jq -r .client_email < ${HOME}/gcp-key.json)
```

**Correct approach:**
```bash
# ✅ gcloud automatically sets account when activating
gcloud auth activate-service-account --key-file=${HOME}/gcp-key.json

# ✅ Get account from gcloud config
ACCOUNT=$(gcloud config get-value account)
```

### Issue 2: "Invalid JSON in GCP service account key"

**Cause:** Secret is not proper base64 or JSON format

**Solution:**

```bash
# Re-encode your service account key
cat key.json | base64 -w 0

# Update GitHub secret with new base64 string
# Settings > Secrets > GCP_SA_KEY > Update
```

### Issue 2: "Permission denied" when accessing GKE

**Cause:** Service account lacks required IAM roles

**Solution:**

```bash
# Grant necessary roles
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/artifactregistry.writer"
```

### Issue 3: "gke-gcloud-auth-plugin not found"

**Cause:** Missing authentication plugin for GKE

**Solution:**

```yaml
- name: Install gke-gcloud-auth-plugin
  run: |
    gcloud components install gke-gcloud-auth-plugin --quiet
```

---

## 📊 Debugging Checklist

When deployment fails with authentication errors:

- [ ] Check secret is properly base64-encoded
- [ ] Verify JSON format: `echo "$SECRET" | base64 -d | jq .`
- [ ] Ensure setup-gcloud runs BEFORE activate-service-account
- [ ] Check service account has correct IAM roles
- [ ] Verify project ID is correct
- [ ] Check gke-gcloud-auth-plugin is installed
- [ ] Review gcloud auth list output
- [ ] Verify GOOGLE_APPLICATION_CREDENTIALS points to correct file

---

## 🎓 Key Takeaways

1. **Order matters**: Setup SDK → Activate account → Use gcloud
2. **Validate early**: Check JSON format before using
3. **Verify always**: Add auth verification steps
4. **Environment variables**: Set GOOGLE_APPLICATION_CREDENTIALS
5. **Explicit config**: Always set project explicitly

---

## 🔗 Related Issues

- **Build job works, Deploy job fails**: Different auth in each job
- **Works locally, fails in Actions**: Missing environment variables
- **Intermittent failures**: SDK version conflicts

---

## 📚 References

- [Google GitHub Actions Auth](https://github.com/google-github-actions/auth)
- [Setup Cloud SDK](https://github.com/google-github-actions/setup-gcloud)
- [GKE Auth Plugin](https://cloud.google.com/blog/products/containers-kubernetes/kubectl-auth-changes-in-gke)

---

_Last Updated: October 11, 2025_  
_Tested with: google-github-actions/setup-gcloud@v2_

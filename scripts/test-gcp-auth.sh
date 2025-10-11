#!/bin/bash
# GCP Authentication Diagnostic Script
# Use this to test authentication locally before pushing to GitHub Actions

set -e

echo "======================================"
echo "GCP Authentication Diagnostic Tool"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gcloud is installed
echo "1️⃣ Checking gcloud installation..."
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud not found! Please install Google Cloud SDK${NC}"
    exit 1
fi
echo -e "${GREEN}✅ gcloud is installed: $(gcloud version | head -n 1)${NC}"
echo ""

# Check if key file exists
echo "2️⃣ Checking service account key file..."
if [ -z "$1" ]; then
    echo -e "${YELLOW}⚠️  Usage: $0 <path-to-service-account-key.json>${NC}"
    echo "   Example: $0 ~/gcp-key.json"
    exit 1
fi

KEY_FILE="$1"
if [ ! -f "$KEY_FILE" ]; then
    echo -e "${RED}❌ Key file not found: $KEY_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Key file exists${NC}"
echo "   Size: $(wc -c < "$KEY_FILE") bytes"
echo ""

# Validate JSON format
echo "3️⃣ Validating JSON format..."
if ! python3 -c "import json; json.load(open('$KEY_FILE'))" 2>/dev/null; then
    echo -e "${RED}❌ Invalid JSON format!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Valid JSON format${NC}"
echo ""

# Extract key information
echo "4️⃣ Extracting service account info..."
CLIENT_EMAIL=$(python3 -c "import json; print(json.load(open('$KEY_FILE'))['client_email'])")
PROJECT_ID=$(python3 -c "import json; print(json.load(open('$KEY_FILE'))['project_id'])")
echo "   Email: $CLIENT_EMAIL"
echo "   Project: $PROJECT_ID"
echo ""

# Test authentication
echo "5️⃣ Testing authentication..."
if ! gcloud auth activate-service-account --key-file="$KEY_FILE" 2>&1; then
    echo -e "${RED}❌ Failed to activate service account!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Service account activated${NC}"
echo ""

# Verify active account
echo "6️⃣ Verifying active account..."
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
if [ -z "$ACTIVE_ACCOUNT" ]; then
    echo -e "${RED}❌ No active account found!${NC}"
    gcloud auth list
    exit 1
fi
echo -e "${GREEN}✅ Active account: $ACTIVE_ACCOUNT${NC}"
echo ""

# Set account explicitly
echo "7️⃣ Setting account explicitly..."
gcloud config set account "$CLIENT_EMAIL"
echo -e "${GREEN}✅ Account set${NC}"
echo ""

# Set project
echo "8️⃣ Setting project..."
gcloud config set project "$PROJECT_ID"
echo -e "${GREEN}✅ Project set${NC}"
echo ""

# Verify configuration
echo "9️⃣ Verifying configuration..."
CONFIGURED_ACCOUNT=$(gcloud config get-value account)
CONFIGURED_PROJECT=$(gcloud config get-value project)
echo "   Account: $CONFIGURED_ACCOUNT"
echo "   Project: $CONFIGURED_PROJECT"

if [ "$CONFIGURED_ACCOUNT" != "$CLIENT_EMAIL" ]; then
    echo -e "${RED}❌ Account mismatch!${NC}"
    exit 1
fi

if [ "$CONFIGURED_PROJECT" != "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Project mismatch!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Configuration matches${NC}"
echo ""

# Test API access
echo "🔟 Testing API access..."
echo "   Testing projects API..."
if gcloud projects describe "$PROJECT_ID" --format="value(projectId)" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ Can access projects API${NC}"
else
    echo -e "   ${YELLOW}⚠️  Cannot access projects API${NC}"
fi

echo "   Testing GKE API..."
if gcloud container clusters list --project="$PROJECT_ID" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ Can access GKE API${NC}"
    echo ""
    echo "   Available clusters:"
    gcloud container clusters list --project="$PROJECT_ID" --format="table(name,location,status)"
else
    echo -e "   ${YELLOW}⚠️  Cannot access GKE API (may need permissions)${NC}"
fi
echo ""

# Check IAM permissions
echo "1️⃣1️⃣ Checking IAM roles..."
echo "   Service account: $CLIENT_EMAIL"
echo ""
if gcloud projects get-iam-policy "$PROJECT_ID" \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:$CLIENT_EMAIL" \
    --format="table(bindings.role)" 2>/dev/null | grep -q "roles/"; then
    echo -e "   ${GREEN}✅ Service account has IAM roles:${NC}"
    gcloud projects get-iam-policy "$PROJECT_ID" \
        --flatten="bindings[].members" \
        --filter="bindings.members:serviceAccount:$CLIENT_EMAIL" \
        --format="value(bindings.role)"
else
    echo -e "   ${YELLOW}⚠️  Could not retrieve IAM roles (may need permissions)${NC}"
fi
echo ""

# Test GKE credentials (if cluster exists)
echo "1️⃣2️⃣ Testing GKE credentials..."
CLUSTERS=$(gcloud container clusters list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null)
if [ -n "$CLUSTERS" ]; then
    FIRST_CLUSTER=$(echo "$CLUSTERS" | head -n 1)
    CLUSTER_ZONE=$(gcloud container clusters list --project="$PROJECT_ID" --filter="name=$FIRST_CLUSTER" --format="value(location)")
    
    echo "   Testing get-credentials for: $FIRST_CLUSTER"
    if gcloud container clusters get-credentials "$FIRST_CLUSTER" \
        --region="$CLUSTER_ZONE" \
        --project="$PROJECT_ID" 2>&1; then
        echo -e "   ${GREEN}✅ Can get GKE credentials${NC}"
        
        # Test kubectl
        if command -v kubectl &> /dev/null; then
            echo ""
            echo "   Testing kubectl access..."
            if kubectl get nodes 2>/dev/null; then
                echo -e "   ${GREEN}✅ kubectl can access cluster${NC}"
            else
                echo -e "   ${YELLOW}⚠️  kubectl cannot access cluster${NC}"
            fi
        fi
    else
        echo -e "   ${RED}❌ Cannot get GKE credentials${NC}"
    fi
else
    echo -e "   ${YELLOW}ℹ️  No clusters found to test${NC}"
fi
echo ""

# Summary
echo "======================================"
echo "Diagnostic Summary"
echo "======================================"
echo -e "${GREEN}✅ All critical checks passed!${NC}"
echo ""
echo "Your service account is properly configured for:"
echo "  - Authentication with GCP"
echo "  - Project access: $PROJECT_ID"
echo "  - Account: $CLIENT_EMAIL"
echo ""
echo "To use in GitHub Actions:"
echo "  1. Encode key: cat $KEY_FILE | base64 -w 0"
echo "  2. Add to GitHub Secrets as GCP_SA_KEY"
echo "  3. Workflow will decode and use automatically"
echo ""
echo "======================================"

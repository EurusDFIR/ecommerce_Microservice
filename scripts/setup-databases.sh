#!/bin/bash

# Setup Databases for E-commerce Microservices
# This script creates Cloud SQL (PostgreSQL) and Firestore instances

set -e

PROJECT_ID="ecommerce-micro-0037"
REGION="asia-southeast1"
ZONE="asia-southeast1-a"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Database Setup for E-commerce System ${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Set project
gcloud config set project $PROJECT_ID

# ============================================
# PART 1: Cloud SQL Setup
# ============================================
echo -e "\n${GREEN}[1/4] Setting up Cloud SQL PostgreSQL...${NC}"

INSTANCE_NAME="ecommerce-postgres"
DB_VERSION="POSTGRES_15"
TIER="db-f1-micro" # Smallest tier for development
ROOT_PASSWORD="Ecommerce2024SecurePass!"

# Enable Cloud SQL Admin API
echo -e "${YELLOW}Enabling Cloud SQL Admin API...${NC}"
gcloud services enable sqladmin.googleapis.com

# Check if instance exists
if gcloud sql instances describe $INSTANCE_NAME --project=$PROJECT_ID 2>/dev/null; then
    echo -e "${YELLOW}Cloud SQL instance '$INSTANCE_NAME' already exists. Skipping creation.${NC}"
else
    echo -e "${YELLOW}Creating Cloud SQL instance (this takes 5-10 minutes)...${NC}"
    gcloud sql instances create $INSTANCE_NAME \
        --database-version=$DB_VERSION \
        --tier=$TIER \
        --region=$REGION \
        --root-password=$ROOT_PASSWORD \
        --storage-type=SSD \
        --storage-size=10GB \
        --storage-auto-increase \
        --backup-start-time=02:00 \
        --retained-backups-count=7 \
        --maintenance-window-day=SUN \
        --maintenance-window-hour=3 \
        --project=$PROJECT_ID
    
    echo -e "${GREEN}✓ Cloud SQL instance created successfully!${NC}"
fi

# Get connection name
CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME --format="value(connectionName)")
echo -e "${GREEN}Connection Name: $CONNECTION_NAME${NC}"

# Create databases
echo -e "\n${YELLOW}Creating databases...${NC}"

# Users database
if gcloud sql databases describe users_db --instance=$INSTANCE_NAME 2>/dev/null; then
    echo -e "${YELLOW}Database 'users_db' already exists.${NC}"
else
    gcloud sql databases create users_db --instance=$INSTANCE_NAME
    echo -e "${GREEN}✓ Created 'users_db'${NC}"
fi

# Products database
if gcloud sql databases describe products_db --instance=$INSTANCE_NAME 2>/dev/null; then
    echo -e "${YELLOW}Database 'products_db' already exists.${NC}"
else
    gcloud sql databases create products_db --instance=$INSTANCE_NAME
    echo -e "${GREEN}✓ Created 'products_db'${NC}"
fi

# Create database users
echo -e "\n${YELLOW}Creating database users...${NC}"

USERS_SERVICE_PASSWORD="UsersService2024!"
PRODUCTS_SERVICE_PASSWORD="ProductsService2024!"

# User for users-service
gcloud sql users create users_service_user \
    --instance=$INSTANCE_NAME \
    --password=$USERS_SERVICE_PASSWORD \
    2>/dev/null || echo -e "${YELLOW}User 'users_service_user' may already exist.${NC}"

# User for products-service
gcloud sql users create products_service_user \
    --instance=$INSTANCE_NAME \
    --password=$PRODUCTS_SERVICE_PASSWORD \
    2>/dev/null || echo -e "${YELLOW}User 'products_service_user' may already exist.${NC}"

echo -e "${GREEN}✓ Database users created${NC}"

# ============================================
# PART 2: Firestore Setup
# ============================================
echo -e "\n${GREEN}[2/4] Setting up Firestore...${NC}"

# Enable Firestore API
echo -e "${YELLOW}Enabling Firestore API...${NC}"
gcloud services enable firestore.googleapis.com

# Create Firestore database (Native mode)
echo -e "${YELLOW}Creating Firestore database...${NC}"
gcloud firestore databases create \
    --location=$REGION \
    --project=$PROJECT_ID \
    2>/dev/null || echo -e "${YELLOW}Firestore database may already exist.${NC}"

echo -e "${GREEN}✓ Firestore setup complete${NC}"

# ============================================
# PART 3: Service Account Setup
# ============================================
echo -e "\n${GREEN}[3/4] Setting up Service Accounts...${NC}"

SA_NAME="ecommerce-services-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Create service account
if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID 2>/dev/null; then
    echo -e "${YELLOW}Service account already exists.${NC}"
else
    gcloud iam service-accounts create $SA_NAME \
        --display-name="E-commerce Services Account" \
        --project=$PROJECT_ID
    echo -e "${GREEN}✓ Service account created${NC}"
fi

# Grant permissions
echo -e "${YELLOW}Granting IAM permissions...${NC}"

# Cloud SQL Client role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/cloudsql.client" \
    --condition=None \
    2>/dev/null || true

# Firestore User role
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/datastore.user" \
    --condition=None \
    2>/dev/null || true

echo -e "${GREEN}✓ IAM permissions granted${NC}"

# Bind service account to Kubernetes
echo -e "${YELLOW}Binding service account to Kubernetes...${NC}"

# Get cluster credentials
gcloud container clusters get-credentials my-ecommerce-cluster \
    --region=$REGION \
    --project=$PROJECT_ID

# Create Kubernetes service account
kubectl create serviceaccount ecommerce-ksa -n ecommerce 2>/dev/null || \
    echo -e "${YELLOW}Kubernetes service account may already exist.${NC}"

# Bind with Workload Identity
gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[ecommerce/ecommerce-ksa]" \
    2>/dev/null || true

kubectl annotate serviceaccount ecommerce-ksa \
    -n ecommerce \
    iam.gke.io/gcp-service-account=$SA_EMAIL \
    --overwrite

echo -e "${GREEN}✓ Service account binding complete${NC}"

# ============================================
# PART 4: Create Kubernetes Secrets
# ============================================
echo -e "\n${GREEN}[4/4] Creating Kubernetes Secrets...${NC}"

# Cloud SQL connection secret
kubectl create secret generic cloudsql-db-credentials \
    -n ecommerce \
    --from-literal=connection_name=$CONNECTION_NAME \
    --from-literal=users_db_name=users_db \
    --from-literal=users_db_user=users_service_user \
    --from-literal=users_db_password=$USERS_SERVICE_PASSWORD \
    --from-literal=products_db_name=products_db \
    --from-literal=products_db_user=products_service_user \
    --from-literal=products_db_password=$PRODUCTS_SERVICE_PASSWORD \
    --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Kubernetes secrets created${NC}"

# ============================================
# Summary
# ============================================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}        Setup Complete!                 ${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${GREEN}Cloud SQL Details:${NC}"
echo -e "  Instance Name: ${YELLOW}$INSTANCE_NAME${NC}"
echo -e "  Connection Name: ${YELLOW}$CONNECTION_NAME${NC}"
echo -e "  Databases: ${YELLOW}users_db, products_db${NC}"
echo -e "  Region: ${YELLOW}$REGION${NC}"

echo -e "\n${GREEN}Firestore Details:${NC}"
echo -e "  Mode: ${YELLOW}Native${NC}"
echo -e "  Location: ${YELLOW}$REGION${NC}"
echo -e "  Collections: ${YELLOW}orders, carts, order_items${NC}"

echo -e "\n${GREEN}Service Account:${NC}"
echo -e "  Email: ${YELLOW}$SA_EMAIL${NC}"
echo -e "  Roles: ${YELLOW}Cloud SQL Client, Firestore User${NC}"

echo -e "\n${GREEN}Connection Strings:${NC}"
echo -e "  Users DB: ${YELLOW}postgresql://users_service_user:[password]@/users_db?host=/cloudsql/$CONNECTION_NAME${NC}"
echo -e "  Products DB: ${YELLOW}postgresql://products_service_user:[password]@/products_db?host=/cloudsql/$CONNECTION_NAME${NC}"

echo -e "\n${YELLOW}Important: Save these credentials securely!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Update service code to use these databases"
echo -e "  2. Add Cloud SQL Proxy sidecar to deployments"
echo -e "  3. Run database migrations"
echo -e "  4. Deploy updated services"

echo -e "\n${GREEN}Database setup script completed successfully!${NC}\n"

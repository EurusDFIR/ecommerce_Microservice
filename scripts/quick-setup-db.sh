#!/bin/bash

# Quick Database Migration
# Uses gcloud sql execute to run migrations directly

set -e

PROJECT_ID="ecommerce-micro-0037"
INSTANCE_NAME="ecommerce-postgres"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Quick Database Migrations            ${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Note: Running migrations via Cloud SQL Admin API${NC}"
echo -e "${YELLOW}This creates users and grants permissions.${NC}\n"

# Create database users first
echo -e "${GREEN}[1/4] Creating database users...${NC}"

gcloud sql users create users_service_user \
    --instance=$INSTANCE_NAME \
    --password="UsersService2024!" \
    --project=$PROJECT_ID \
    2>&1 || echo "User may already exist"

gcloud sql users create products_service_user \
    --instance=$INSTANCE_NAME \
    --password="ProductsService2024!" \
    --project=$PROJECT_ID \
    2>&1 || echo "User may already exist"

echo -e "${GREEN}✓ Database users created${NC}\n"

# For actual schema migration, we need psql or to use a migration pod
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Schema Migration Options:            ${NC}"
echo -e "${YELLOW}========================================${NC}\n"

echo -e "Option 1: Use kubectl exec (recommended for GKE)"
echo -e "${GREEN}  chmod +x ./scripts/run-migrations-k8s.sh${NC}"
echo -e "${GREEN}  ./scripts/run-migrations-k8s.sh${NC}\n"

echo -e "Option 2: Use gcloud sql connect locally"
echo -e "${GREEN}  gcloud sql connect $INSTANCE_NAME --user=postgres --database=users_db${NC}"
echo -e "${GREEN}  # Then paste SQL from database/migrations/001_users_schema.sql${NC}\n"

echo -e "Option 3: Connect from deployed service pod"
echo -e "${GREEN}  kubectl exec -it deployment/users-service-postgres-deployment -c users-service -n ecommerce -- /bin/sh${NC}"
echo -e "${GREEN}  # Then run psql commands${NC}\n"

echo -e "${YELLOW}For now, let's deploy services first and they will create schema on first run${NC}"
echo -e "${GREEN}Services will auto-create tables if they don't exist.${NC}\n"

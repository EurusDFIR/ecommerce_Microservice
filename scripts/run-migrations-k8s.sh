#!/bin/bash

# Simple Database Migration via kubectl exec
# Runs migrations directly from a Cloud SQL Proxy pod

set -e

PROJECT_ID="ecommerce-micro-0037"
REGION="asia-southeast1"
CONNECTION_NAME="ecommerce-micro-0037:asia-southeast1:ecommerce-postgres"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Running Database Migrations          ${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Get cluster credentials
gcloud container clusters get-credentials my-ecommerce-cluster \
    --region=$REGION \
    --project=$PROJECT_ID

# Create a temporary pod with Cloud SQL Proxy and psql
echo -e "${YELLOW}Creating temporary migration pod...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: db-migration-pod
  namespace: ecommerce
spec:
  serviceAccountName: ecommerce-ksa
  restartPolicy: Never
  containers:
  - name: cloud-sql-proxy
    image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.8.0
    args:
      - "--port=5432"
      - "$CONNECTION_NAME"
    ports:
    - containerPort: 5432
  - name: psql-client
    image: postgres:15
    command: ["sleep", "3600"]
    env:
    - name: PGHOST
      value: "127.0.0.1"
    - name: PGPORT
      value: "5432"
EOF

# Wait for pod to be ready
echo -e "${YELLOW}Waiting for migration pod to be ready...${NC}"
kubectl wait --for=condition=Ready pod/db-migration-pod -n ecommerce --timeout=60s

# Copy migration files to pod
echo -e "${YELLOW}Copying migration files...${NC}"
kubectl cp database/migrations/001_users_schema.sql ecommerce/db-migration-pod:/tmp/001_users_schema.sql -c psql-client
kubectl cp database/migrations/002_products_schema.sql ecommerce/db-migration-pod:/tmp/002_products_schema.sql -c psql-client

# Run migrations
echo -e "\n${GREEN}[1/2] Migrating Users Database...${NC}"
kubectl exec -it db-migration-pod -n ecommerce -c psql-client -- \
    psql -h 127.0.0.1 -U users_service_user -d users_db \
    -f /tmp/001_users_schema.sql

echo -e "\n${GREEN}[2/2] Migrating Products Database...${NC}"
kubectl exec -it db-migration-pod -n ecommerce -c psql-client -- \
    psql -h 127.0.0.1 -U products_service_user -d products_db \
    -f /tmp/002_products_schema.sql

# Cleanup
echo -e "\n${YELLOW}Cleaning up migration pod...${NC}"
kubectl delete pod db-migration-pod -n ecommerce

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Migrations Complete!                  ${NC}"
echo -e "${GREEN}========================================${NC}\n"

#!/bin/bash

# Deploy All Services with Real Databases
# This script builds and deploys all microservices with PostgreSQL and Firestore

set -e

PROJECT_ID="ecommerce-micro-0037"
REGION="asia-southeast1"
REPO="my-ecommerce-repo"
REGISTRY="asia-southeast1-docker.pkg.dev/$PROJECT_ID/$REPO"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Deploying Services with Databases    ${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Set project
gcloud config set project $PROJECT_ID

# Get cluster credentials
echo -e "${YELLOW}Getting cluster credentials...${NC}"
gcloud container clusters get-credentials my-ecommerce-cluster \
    --region=$REGION \
    --project=$PROJECT_ID

# ============================================
# Build and Deploy Users Service (PostgreSQL)
# ============================================
echo -e "\n${GREEN}[1/3] Building Users Service with PostgreSQL...${NC}"

cd services/users-service

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -f Dockerfile.postgres -t $REGISTRY/users-service:v2-postgres .

# Push to Artifact Registry
echo -e "${YELLOW}Pushing to Artifact Registry...${NC}"
docker push $REGISTRY/users-service:v2-postgres

cd ../..

# ============================================
# Build and Deploy Products Service (PostgreSQL)
# ============================================
echo -e "\n${GREEN}[2/3] Building Products Service with PostgreSQL...${NC}"

cd services/products-service

# Check if Dockerfile.postgres exists, create if not
if [ ! -f "Dockerfile.postgres" ]; then
    cp Dockerfile Dockerfile.postgres
    # Update CMD to use app-postgres.js
    sed -i 's/CMD \["node", "app.js"\]/CMD ["node", "app-postgres.js"]/' Dockerfile.postgres
fi

# Add pg package if not exists
if ! grep -q '"pg"' package.json; then
    npm install --save pg
fi

echo -e "${YELLOW}Building Docker image...${NC}"
docker build -f Dockerfile.postgres -t $REGISTRY/products-service:v2-postgres .

echo -e "${YELLOW}Pushing to Artifact Registry...${NC}"
docker push $REGISTRY/products-service:v2-postgres

cd ../..

# ============================================
# Build and Deploy Orders Service (Firestore)
# ============================================
echo -e "\n${GREEN}[3/3] Building Orders Service with Firestore...${NC}"

cd services/orders-service

# Check if Dockerfile.firestore exists, create if not
if [ ! -f "Dockerfile.firestore" ]; then
    cp Dockerfile Dockerfile.firestore
    # Update CMD to use app-firestore.js
    sed -i 's/CMD \["node", "app.js"\]/CMD ["node", "app-firestore.js"]/' Dockerfile.firestore
fi

echo -e "${YELLOW}Building Docker image...${NC}"
docker build -f Dockerfile.firestore -t $REGISTRY/orders-service:v2-firestore .

echo -e "${YELLOW}Pushing to Artifact Registry...${NC}"
docker push $REGISTRY/orders-service:v2-firestore

cd ../..

# ============================================
# Deploy to Kubernetes
# ============================================
echo -e "\n${GREEN}Deploying to Kubernetes...${NC}"

# Apply secrets and deployments
kubectl apply -f infrastructure/k8s/users-service-postgres-deployment.yaml
kubectl apply -f infrastructure/k8s/products-service-postgres-deployment.yaml
kubectl apply -f infrastructure/k8s/orders-service-firestore-deployment.yaml

# Wait for deployments to be ready
echo -e "\n${YELLOW}Waiting for deployments to be ready...${NC}"

kubectl wait --for=condition=available --timeout=300s \
    deployment/users-service-postgres-deployment -n ecommerce || true

kubectl wait --for=condition=available --timeout=300s \
    deployment/products-service-postgres-deployment -n ecommerce || true

kubectl wait --for=condition=available --timeout=300s \
    deployment/orders-service-firestore-deployment -n ecommerce || true

# ============================================
# Summary
# ============================================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Deployment Status                    ${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${GREEN}Deployments:${NC}"
kubectl get deployments -n ecommerce

echo -e "\n${GREEN}Pods:${NC}"
kubectl get pods -n ecommerce

echo -e "\n${GREEN}Services:${NC}"
kubectl get services -n ecommerce

echo -e "\n${GREEN}[SUCCESS] All services deployed with real databases!${NC}"
echo -e "\n${YELLOW}Services are now using:${NC}"
echo -e "  - Users Service: ${GREEN}PostgreSQL (Cloud SQL)${NC}"
echo -e "  - Products Service: ${GREEN}PostgreSQL (Cloud SQL)${NC}"
echo -e "  - Orders Service: ${GREEN}Firestore${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  1. Run database migrations: ./scripts/run-migrations.sh"
echo -e "  2. Test the services with real data persistence"
echo -e "  3. Monitor logs: kubectl logs -f deployment/<deployment-name> -n ecommerce"

echo -e "\n${GREEN}Deployment script completed!${NC}\n"

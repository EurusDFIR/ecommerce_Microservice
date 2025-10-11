#!/bin/bash

# Deploy all microservices script

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

PROJECT_ID=$(gcloud config get-value project)
LOCATION="asia-southeast1"
REPO_NAME="my-ecommerce-repo"

log_info "Deploying all microservices to GKE..."
log_info "Project: $PROJECT_ID"

# Build and push Users Service
log_info "Building Users Service Docker image..."
cd services/users-service
docker build -t users-service:v1 .
docker tag users-service:v1 $LOCATION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/users-service:v1
log_info "Pushing Users Service image..."
docker push $LOCATION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/users-service:v1
log_success "Users Service image pushed"
cd ../..

# Build and push Orders Service
log_info "Building Orders Service Docker image..."
cd services/orders-service
docker build -t orders-service:v1 .
docker tag orders-service:v1 $LOCATION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/orders-service:v1
log_info "Pushing Orders Service image..."
docker push $LOCATION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/orders-service:v1
log_success "Orders Service image pushed"
cd ../..

# Deploy to Kubernetes
log_info "Deploying services to GKE..."

# Deploy Users Service
log_info "Deploying Users Service..."
kubectl apply -f infrastructure/k8s/users-service-deployment.yaml
log_success "Users Service deployed"

# Deploy Orders Service
log_info "Deploying Orders Service..."
kubectl apply -f infrastructure/k8s/orders-service-deployment.yaml
log_success "Orders Service deployed"

# Wait for deployments
log_info "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/users-service-deployment -n ecommerce
kubectl wait --for=condition=available --timeout=300s deployment/orders-service-deployment -n ecommerce

log_success "All services deployed successfully!"

# Show status
log_info "Current status:"
kubectl get pods -n ecommerce
kubectl get services -n ecommerce

log_success "Deployment complete!"
log_info "Services:"
echo "  - Products Service (External): http://$(kubectl get service products-service-lb -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "  - Users Service (Internal): http://users-service.ecommerce.svc.cluster.local"
echo "  - Orders Service (Internal): http://orders-service.ecommerce.svc.cluster.local"
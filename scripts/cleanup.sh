#!/bin/bash

# Cleanup script để xóa tài nguyên GCP

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Confirm deletion
confirm_deletion() {
    echo ""
    log_warning "This script will delete the following resources:"
    echo "  - GKE cluster: my-ecommerce-cluster"
    echo "  - Kubernetes deployments and services"
    echo "  - Docker images in Artifact Registry (optional)"
    echo ""
    
    read -p "Are you sure you want to proceed? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
}

# Delete Kubernetes resources
cleanup_k8s() {
    log_info "Cleaning up Kubernetes resources..."
    
    # Delete deployment and services
    if kubectl get namespace ecommerce &> /dev/null; then
        kubectl delete -f infrastructure/k8s/products-service-deployment.yaml --ignore-not-found=true
        log_success "Kubernetes resources deleted"
    else
        log_warning "Namespace 'ecommerce' not found"
    fi
}

# Delete GKE cluster
delete_cluster() {
    log_info "Deleting GKE cluster..."
    
    CLUSTER_NAME="my-ecommerce-cluster"
    REGION="asia-southeast1"
    
    if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" &> /dev/null; then
        log_warning "Deleting cluster (this may take 5-10 minutes)..."
        gcloud container clusters delete "$CLUSTER_NAME" --region="$REGION" --quiet
        log_success "Cluster deleted"
    else
        log_warning "Cluster $CLUSTER_NAME not found"
    fi
}

# Optional: Delete Artifact Registry images
cleanup_images() {
    echo ""
    read -p "Do you want to delete Docker images from Artifact Registry? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Deleting Docker images..."
        
        PROJECT_ID=$(gcloud config get-value project)
        LOCATION="asia-southeast1"
        REPO_NAME="my-ecommerce-repo"
        
        # List and delete images
        gcloud artifacts docker images delete \
            "$LOCATION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/products-service:v1" \
            --quiet 2>/dev/null || log_warning "Image not found or already deleted"
        
        log_success "Images deleted"
    fi
}

# Optional: Delete Artifact Registry repository
cleanup_registry() {
    echo ""
    read -p "Do you want to delete the entire Artifact Registry repository? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Deleting Artifact Registry repository..."
        
        LOCATION="asia-southeast1"
        REPO_NAME="my-ecommerce-repo"
        
        gcloud artifacts repositories delete "$REPO_NAME" \
            --location="$LOCATION" \
            --quiet 2>/dev/null || log_warning "Repository not found or already deleted"
        
        log_success "Repository deleted"
    fi
}

# Main cleanup
main() {
    log_info "E-commerce Microservices Cleanup"
    
    confirm_deletion
    cleanup_k8s
    delete_cluster
    cleanup_images
    cleanup_registry
    
    log_success "Cleanup completed!"
    log_info "Remaining resources (if any):"
    echo "  - Local Docker images (run: docker image prune)"
    echo "  - GCP project (if you want to delete entirely)"
    echo ""
    log_info "To check remaining GCP resources:"
    echo "  gcloud compute instances list"
    echo "  gcloud container clusters list"
    echo "  gcloud artifacts repositories list"
}

main "$@"
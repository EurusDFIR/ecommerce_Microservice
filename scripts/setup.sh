#!/bin/bash

# Setup script cho E-commerce Microservices project
# Chạy script này sau khi đã setup billing

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if gcloud is installed and authenticated
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Installing..."
        gcloud components install kubectl
    fi
    
    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "Please authenticate with gcloud first: gcloud auth login"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get project ID
get_project_id() {
    PROJECT_ID=$(gcloud config get-value project)
    if [ -z "$PROJECT_ID" ]; then
        log_error "No project set. Please set a project: gcloud config set project PROJECT_ID"
        exit 1
    fi
    log_info "Using project: $PROJECT_ID"
}

# Enable required APIs
enable_apis() {
    log_info "Enabling required APIs..."
    
    apis=(
        "artifactregistry.googleapis.com"
        "container.googleapis.com" 
        "cloudbuild.googleapis.com"
        "sql-component.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        log_info "Enabling $api..."
        gcloud services enable "$api"
    done
    
    log_success "All APIs enabled"
}

# Create Artifact Registry repository
create_artifact_registry() {
    log_info "Creating Artifact Registry repository..."
    
    REPO_NAME="my-ecommerce-repo"
    LOCATION="asia-southeast1"
    
    # Check if repository already exists
    if gcloud artifacts repositories describe "$REPO_NAME" --location="$LOCATION" &> /dev/null; then
        log_warning "Repository $REPO_NAME already exists"
    else
        gcloud artifacts repositories create "$REPO_NAME" \
            --repository-format=docker \
            --location="$LOCATION" \
            --description="Docker repository for e-commerce project"
        log_success "Repository $REPO_NAME created"
    fi
    
    # Configure Docker authentication
    log_info "Configuring Docker authentication..."
    gcloud auth configure-docker "$LOCATION-docker.pkg.dev"
    log_success "Docker authentication configured"
}

# Build and push Docker image
build_and_push_image() {
    log_info "Building and pushing Products Service Docker image..."
    
    LOCATION="asia-southeast1"
    REPO_NAME="my-ecommerce-repo"
    SERVICE_NAME="products-service"
    VERSION="v1"
    
    IMAGE_TAG="$LOCATION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$SERVICE_NAME:$VERSION"
    
    # Navigate to products-service directory
    cd "services/products-service"
    
    # Build image
    log_info "Building Docker image..."
    docker build -t "$SERVICE_NAME:$VERSION" .
    
    # Tag for registry
    log_info "Tagging image for registry..."
    docker tag "$SERVICE_NAME:$VERSION" "$IMAGE_TAG"
    
    # Push to registry
    log_info "Pushing image to registry..."
    docker push "$IMAGE_TAG"
    
    log_success "Image pushed successfully: $IMAGE_TAG"
    
    # Return to project root
    cd "../.."
}

# Update Kubernetes manifests with correct PROJECT_ID
update_k8s_manifests() {
    log_info "Updating Kubernetes manifests with PROJECT_ID..."
    
    # Create a copy of the template if needed
    K8S_FILE="infrastructure/k8s/products-service-deployment.yaml"
    
    # Replace PROJECT_ID in the file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/PROJECT_ID/$PROJECT_ID/g" "$K8S_FILE"
    else
        # Linux
        sed -i "s/PROJECT_ID/$PROJECT_ID/g" "$K8S_FILE"
    fi
    
    log_success "Kubernetes manifests updated"
}

# Create GKE cluster
create_gke_cluster() {
    log_info "Creating GKE cluster..."
    
    CLUSTER_NAME="my-ecommerce-cluster"
    REGION="asia-southeast1"
    
    # Check if cluster already exists
    if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" &> /dev/null; then
        log_warning "Cluster $CLUSTER_NAME already exists"
    else
        log_info "Creating GKE cluster (this may take 5-10 minutes)..."
        gcloud container clusters create-auto "$CLUSTER_NAME" \
            --region="$REGION" \
            --release-channel=regular
        log_success "Cluster $CLUSTER_NAME created"
    fi
    
    # Get credentials
    log_info "Getting cluster credentials..."
    gcloud container clusters get-credentials "$CLUSTER_NAME" --region="$REGION"
    log_success "Cluster credentials configured"
}

# Deploy to GKE
deploy_to_gke() {
    log_info "Deploying Products Service to GKE..."
    
    K8S_FILE="infrastructure/k8s/products-service-deployment.yaml"
    
    # Apply the manifests
    kubectl apply -f "$K8S_FILE"
    
    log_info "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/products-service-deployment -n ecommerce
    
    log_success "Deployment completed successfully"
    
    # Show status
    log_info "Deployment status:"
    kubectl get pods -n ecommerce
    kubectl get services -n ecommerce
    
    # Wait for external IP
    log_info "Waiting for external IP to be assigned..."
    log_warning "This may take a few minutes..."
    
    while true; do
        EXTERNAL_IP=$(kubectl get service products-service-lb -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ]; then
            break
        fi
        echo -n "."
        sleep 10
    done
    
    echo ""
    log_success "External IP assigned: $EXTERNAL_IP"
    
    # Test the deployment
    log_info "Testing the deployment..."
    sleep 30  # Give it time to fully start
    
    if curl -f "http://$EXTERNAL_IP/health" > /dev/null 2>&1; then
        log_success "Health check passed!"
        log_success "API URL: http://$EXTERNAL_IP"
        log_success "Test endpoints:"
        echo "  - Health: http://$EXTERNAL_IP/health"
        echo "  - Products: http://$EXTERNAL_IP/products"
        echo "  - Categories: http://$EXTERNAL_IP/categories"
    else
        log_warning "Health check failed. The service might still be starting up."
        log_info "Try again in a few minutes: curl http://$EXTERNAL_IP/health"
    fi
}

# Main execution
main() {
    log_info "Starting E-commerce Microservices setup..."
    
    check_prerequisites
    get_project_id
    enable_apis
    create_artifact_registry
    build_and_push_image
    update_k8s_manifests
    create_gke_cluster
    deploy_to_gke
    
    log_success "Setup completed successfully!"
    log_info "Your Products Service is now running on GKE"
    log_info "Next steps:"
    echo "  1. Test your APIs using the URLs provided above"
    echo "  2. Monitor your deployment: kubectl get pods -n ecommerce"
    echo "  3. View logs: kubectl logs -f deployment/products-service-deployment -n ecommerce"
    echo "  4. Scale your deployment: kubectl scale deployment products-service-deployment -n ecommerce --replicas=3"
}

# Run main function
main "$@"
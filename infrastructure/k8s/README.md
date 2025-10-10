# Kubernetes Deployment Scripts

## Chuẩn bị

Đảm bảo bạn đã:

1. Kích hoạt billing cho GCP project
2. Cài đặt và cấu hình `kubectl`
3. Push Docker image lên Artifact Registry

## Cập nhật PROJECT_ID

Trước khi deploy, cần cập nhật PROJECT_ID trong file deployment:

```bash
# Lấy PROJECT_ID hiện tại
export PROJECT_ID=$(gcloud config get-value project)
echo "Project ID: $PROJECT_ID"

# Cập nhật file deployment
sed -i "s/PROJECT_ID/$PROJECT_ID/g" infrastructure/k8s/products-service-deployment.yaml
```

## Deploy lên GKE

### 1. Tạo GKE Cluster (nếu chưa có)

```bash
gcloud container clusters create-auto my-ecommerce-cluster \
    --region=asia-southeast1 \
    --release-channel=regular
```

### 2. Cấu hình kubectl

```bash
gcloud container clusters get-credentials my-ecommerce-cluster \
    --region=asia-southeast1
```

### 3. Deploy application

```bash
# Deploy Products Service
kubectl apply -f infrastructure/k8s/products-service-deployment.yaml

# Kiểm tra deployment
kubectl get deployments -n ecommerce
kubectl get pods -n ecommerce
kubectl get services -n ecommerce
```

### 4. Kiểm tra External IP

```bash
# Chờ External IP được cấp phát
kubectl get service products-service-lb -n ecommerce --watch

# Khi có External IP, test API
export EXTERNAL_IP=$(kubectl get service products-service-lb -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$EXTERNAL_IP/health
curl http://$EXTERNAL_IP/products
```

## Scaling

### Scale up/down replicas

```bash
# Scale to 3 replicas
kubectl scale deployment products-service-deployment -n ecommerce --replicas=3

# Scale down to 1 replica
kubectl scale deployment products-service-deployment -n ecommerce --replicas=1
```

### Auto-scaling (HPA)

```bash
# Enable metrics server (nếu chưa có)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Tạo HPA
kubectl autoscale deployment products-service-deployment -n ecommerce --cpu-percent=70 --min=2 --max=10

# Kiểm tra HPA
kubectl get hpa -n ecommerce
```

## Monitoring & Debugging

### View logs

```bash
# Logs của tất cả pods
kubectl logs -f deployment/products-service-deployment -n ecommerce

# Logs của một pod cụ thể
kubectl logs -f <pod-name> -n ecommerce
```

### Describe resources

```bash
# Deployment details
kubectl describe deployment products-service-deployment -n ecommerce

# Pod details
kubectl describe pod <pod-name> -n ecommerce

# Service details
kubectl describe service products-service-lb -n ecommerce
```

### Exec into container

```bash
# Shell into container
kubectl exec -it <pod-name> -n ecommerce -- /bin/bash

# Run command in container
kubectl exec <pod-name> -n ecommerce -- curl localhost:8080/health
```

## Clean up

### Xóa resources

```bash
# Xóa deployment và services
kubectl delete -f infrastructure/k8s/products-service-deployment.yaml

# Xóa namespace (cẩn thận!)
kubectl delete namespace ecommerce
```

### Xóa cluster

```bash
# Xóa toàn bộ cluster (cẩn thận!)
gcloud container clusters delete my-ecommerce-cluster --region=asia-southeast1
```

## Troubleshooting

### Common issues:

1. **ImagePullBackOff**: Docker image không tồn tại hoặc permission issues

   ```bash
   kubectl describe pod <pod-name> -n ecommerce
   ```

2. **CrashLoopBackOff**: Application crash khi start

   ```bash
   kubectl logs <pod-name> -n ecommerce
   ```

3. **Service không accessible**: Check external IP và firewall rules

   ```bash
   kubectl get services -n ecommerce
   gcloud compute firewall-rules list
   ```

4. **Resource limits**: Pods bị killed do resource constraints
   ```bash
   kubectl top pods -n ecommerce
   kubectl describe pod <pod-name> -n ecommerce
   ```

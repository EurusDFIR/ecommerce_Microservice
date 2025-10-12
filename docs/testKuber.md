1. Kiểm tra Khả năng Tự phục hồi (Self-Healing)

Terminal 1 (Giám sát): Chạy lệnh này và để nó chạy liên tục.

kubectl get pods -n ecommerce -w

Terminal 2 (Hành động): Chạy lệnh này để xóa một pod bất kỳ.

kubectl delete pod <tên-pod-cần-xóa> -n ecommerce

2. Kiểm tra Khả năng Mở rộng (Scaling)
   Để tăng số lượng pod (Scale Up):
   kubectl scale deployment <tên-deployment> -n ecommerce --replicas=5

Để giảm số lượng pod (Scale Down):

kubectl scale deployment <tên-deployment> -n ecommerce --replicas=2

kubectl get pods -n ecommerce -w # xac nhan dang run
kubectl get deployments -n ecommerce # xac nhan healthy

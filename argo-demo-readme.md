# Hướng Dẫn Demo Sự Lợi Hại của ArgoCD (GitOps)

Tài liệu này hướng dẫn cách thực hiện 3 kịch bản thực tế để chứng minh sức mạnh của ArgoCD trong việc quản lý hệ thống Kubernetes theo luồng GitOps.

---

## Kịch Bản 1: Phân Phối Liên Tục (Continuous Delivery)
**Mục đích:** Thay đổi cấu hình ứng dụng trên Git và xem EKS tự động cập nhật mà không cần gõ lệnh.

**Các bước thực hiện:**
1. Mở file `helm-chart/values.yaml` trong dự án.
2. Tìm đến service mà bạn muốn thay đổi (Ví dụ: `checkoutService`).
3. Chỉnh sửa một thông số, ví dụ nâng số lượng `replicas: 2`.
4. Mở Terminal, check trạng thái ban đầu của Pods:
   ```bash
   kubectl get pods -n onlineboutique
   ```
5. Commit thay đổi lên Git:
   ```bash
   git add helm-chart/values.yaml
   git commit -m "demo: scale checkoutService to 2 replicas"
   git push origin main
   ```
6. **Kết quả:** Quét lại `kubectl get pods -n onlineboutique`, bạn sẽ thấy một pod mới của `checkoutservice` tự động được ArgoCD deploy.

---

## Kịch Bản 2: Tự Phục Hồi (Self-Healing)
**Mục đích:** Mô phỏng thảm họa khi một tài nguyên bị xóa nhầm trên Server và xem ArgoCD tự khôi phục nó tức thì.

**Các bước thực hiện:**
1. Xóa thẳng tay một Deployment trên Kubernetes:
   ```bash
   kubectl delete deployment checkoutservice -n onlineboutique
   ```
2. Ngay lập tức kiểm tra lại danh sách pods:
   ```bash
   kubectl get pods -n onlineboutique
   ```
3. **Kết quả:** ArgoCD phát hiện trạng thái thực tế không khớp với trạng thái trên Git (Single Source of Truth), do `selfHeal: true` đang bật, ArgoCD đã tự động gọi API tạo lại Deployment `checkoutservice` bị mất. Các pod mới lập tức xuất hiện trở lại.

---

## Kịch Bản 3: Chống Bỏ Quên Rác (Pruning / Garbage Collection)
**Mục đích:** Xóa một tính năng khỏi Git và để ArgoCD dọn dẹp nó khỏi Server tự động.

**Các bước thực hiện:**
1. Kiểm tra lại danh sách các pods, bạn sẽ thấy pod của `emailservice` đang chạy:
   ```bash
   kubectl get pods -n onlineboutique
   ```
2. Mở file `helm-chart/values.yaml`, tìm đến phần cấu hình cho `emailService`.
3. Đổi giá trị `create` thành `false`:
   ```yaml
   emailService:
     create: false
     name: emailservice
   ```
4. Commit thay đổi lên Git:
   ```bash
   git add helm-chart/values.yaml
   git commit -m "demo: prune emailService"
   git push origin main
   ```
5. (Nếu muốn thấy ngay) Ép ArgoCD quét lại Git: `kubectl annotate application onlineboutique-dev -n argocd argocd.argoproj.io/refresh=hard`
6. **Kết quả:** Kiểm tra lại với lệnh `kubectl get pods -n onlineboutique`. Toàn bộ Pods và resource liên quan đến `emailservice` đã bị ArgoCD rút khỏi EKS (Terminating/Deleted). Máy chủ được dọn dẹp sạch sẽ mà bạn không phải mất công chạy lệnh xóa thủ công nào!

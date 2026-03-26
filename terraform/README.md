# Terraform Infrastructure - Online Boutique

## Cấu trúc thư mục

```
terraform/
├── environments/           # Cấu hình cho từng môi trường
│   ├── shared/            # ECR (dùng chung)
│   ├── dev/               # Development
│   └── prod/              # Production
│
└── modules/               # Reusable modules
    ├── ecr/               # ECR repositories
    ├── vpc/               # VPC, subnets, NAT
    └── eks/               # EKS cluster & nodes
```

## Tối ưu chi phí theo môi trường

### Development (~$120-140/tháng)
- **1 NAT Gateway** (tiết kiệm ~$32/tháng)
- **SPOT instances** (tiết kiệm 60-90% so với On-Demand)
- **Nodes nhỏ hơn**: t3.medium
- **Ít nodes hơn**: min=1, max=3
- **Không có EKS logging** (tiết kiệm CloudWatch costs)

### Production (~$330-400/tháng)
- **2 NAT Gateways** (High Availability)
- **ON_DEMAND instances** (ổn định, không bị interrupt)
- **Nodes lớn hơn**: t3.large, t3.xlarge
- **Nhiều nodes hơn**: min=2, max=10
- **EKS logging enabled** (audit, API logs)

## Cách sử dụng

### 1. Deploy ECR (một lần duy nhất)

```bash
cd terraform/environments/shared
terraform init
terraform plan
terraform apply
```

### 2. Deploy Dev Environment

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Deploy Prod Environment

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

### 4. Kết nối kubectl

Sau khi deploy xong, chạy command từ output:

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name online-boutique-dev
# hoặc
aws eks update-kubeconfig --region ap-southeast-1 --name online-boutique-prod
```

## Network Layout

| Environment | VPC CIDR     | Public Subnets          | Private Subnets           |
|-------------|--------------|-------------------------|---------------------------|
| Dev         | 10.0.0.0/16  | 10.0.0.0/22, 10.0.4.0/22| 10.0.8.0/22, 10.0.12.0/22|
| Prod        | 10.1.0.0/16  | 10.1.0.0/22, 10.1.4.0/22| 10.1.8.0/22, 10.1.12.0/22|

## Các biến quan trọng có thể customize

| Variable | Dev Default | Prod Default | Mô tả |
|----------|-------------|--------------|-------|
| `single_nat_gateway` | true | false | Dùng 1 hay nhiều NAT |
| `capacity_type` | SPOT | ON_DEMAND | Loại EC2 |
| `node_min_size` | 1 | 2 | Min nodes |
| `node_max_size` | 3 | 10 | Max nodes |
| `instance_types` | t3.medium | t3.large | Loại instance |

## Destroy

```bash
# Xóa theo thứ tự ngược
cd terraform/environments/prod && terraform destroy
cd terraform/environments/dev && terraform destroy
cd terraform/environments/shared && terraform destroy
```

## Best Practices đã áp dụng

1. **Modules tái sử dụng**: VPC, EKS, ECR modules dùng chung cho mọi môi trường
2. **Tách biệt state files**: Mỗi environment có state riêng
3. **Tags nhất quán**: Dễ tracking costs
4. **EKS tags cho subnets**: Auto-detect cho Load Balancers
5. **OIDC Provider**: Sẵn sàng cho IRSA (IAM Roles for Service Accounts)
6. **Lifecycle policies**: Tự động dọn dẹp ECR images

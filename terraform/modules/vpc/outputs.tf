# =============================================================================
# VPC MODULE OUTPUTS
# =============================================================================

output "vpc_id" {
  description = "ID của VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block của VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List IDs của public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List IDs của private subnets (cho EKS worker nodes)"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ips" {
  description = "Public IPs của NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "ID của Internet Gateway"
  value       = aws_internet_gateway.main.id
}

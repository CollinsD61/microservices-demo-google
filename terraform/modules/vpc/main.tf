# =============================================================================
# VPC MODULE - Tối ưu cho EKS và tiết kiệm chi phí
# =============================================================================

locals {
  # Tên cho các resources
  name_prefix = "${var.project_name}-${var.environment}"

  # Tính toán số AZs thực tế sử dụng
  azs_count = length(var.availability_zones)
}

# =============================================================================
# VPC
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# =============================================================================
# INTERNET GATEWAY - Cho public subnets
# =============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# =============================================================================
# PUBLIC SUBNETS - Cho Load Balancer, NAT Gateway
# =============================================================================

resource "aws_subnet" "public" {
  count = local.azs_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  # Tags bắt buộc cho EKS để tự động tạo Load Balancer
  tags = merge(var.tags, {
    Name                                        = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# =============================================================================
# PRIVATE SUBNETS - Cho EKS Worker Nodes
# =============================================================================

resource "aws_subnet" "private" {
  count = local.azs_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Tags bắt buộc cho EKS internal load balancers
  tags = merge(var.tags, {
    Name                                        = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# =============================================================================
# ELASTIC IP - Cho NAT Gateway
# =============================================================================

resource "aws_eip" "nat" {
  # Dev: 1 NAT Gateway để tiết kiệm (~$32/tháng mỗi NAT)
  # Prod: 1 NAT Gateway mỗi AZ cho High Availability
  count  = var.single_nat_gateway ? 1 : local.azs_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# NAT GATEWAY - Cho private subnets ra internet
# =============================================================================

resource "aws_nat_gateway" "main" {
  count = var.single_nat_gateway ? 1 : local.azs_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# ROUTE TABLES
# =============================================================================

# Public Route Table - Chung cho tất cả public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = local.azs_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables
resource "aws_route_table" "private" {
  # Nếu single_nat_gateway: 1 route table dùng chung
  # Nếu không: mỗi AZ có route table riêng
  count  = var.single_nat_gateway ? 1 : local.azs_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count = local.azs_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

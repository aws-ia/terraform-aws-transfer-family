# VPC
resource "aws_vpc" "main" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    { Name = "${var.name_prefix}-vpc" }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(
    local.common_tags,
    { Name = "${var.name_prefix}-igw" }
  )
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Public Subnets
resource "aws_subnet" "public" {
  count = var.create_vpc ? min(3, length(data.aws_availability_zones.available.names)) : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-public-subnet-${count.index + 1}"
      Type = "Public"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count = var.create_vpc ? min(3, length(data.aws_availability_zones.available.names)) : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name_prefix}-private-subnet-${count.index + 1}"
      Type = "Private"
    }
  )
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.create_vpc ? min(3, length(data.aws_availability_zones.available.names)) : 0

  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    local.common_tags,
    { Name = "${var.name_prefix}-nat-eip-${count.index + 1}" }
  )
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = var.create_vpc ? min(3, length(data.aws_availability_zones.available.names)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    local.common_tags,
    { Name = "${var.name_prefix}-nat-gateway-${count.index + 1}" }
  )
}

# Public Route Table
resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(
    local.common_tags,
    { Name = "${var.name_prefix}-public-rt" }
  )
}

# Private Route Tables
resource "aws_route_table" "private" {
  count = var.create_vpc ? min(3, length(data.aws_availability_zones.available.names)) : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    local.common_tags,
    { Name = "${var.name_prefix}-private-rt-${count.index + 1}" }
  )
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count = var.create_vpc ? min(3, length(data.aws_availability_zones.available.names)) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count = var.create_vpc ? min(3, length(data.aws_availability_zones.available.names)) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  count = var.create_vpc ? 1 : 0

  name_prefix = "${var.name_prefix}-lambda-"
  description = "Security group for Transfer Custom IdP Lambda"
  vpc_id      = aws_vpc.main[0].id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    { Name = "${var.name_prefix}-lambda-sg" }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Endpoints for private connectivity
resource "aws_vpc_endpoint" "s3" {
  count = var.create_vpc ? 1 : 0

  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(
    local.common_tags,
    { Name = "${var.name_prefix}-s3-endpoint" }
  )
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.create_vpc ? 1 : 0

  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = merge(
    local.common_tags,
    { Name = "${var.name_prefix}-dynamodb-endpoint" }
  )
}

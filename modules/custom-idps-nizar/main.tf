data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Resources
resource "aws_vpc" "main" {
  count      = var.create_vpc ? 1 : 0
  cidr_block = var.vpc_cidr
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(var.tags, {
    Name = "${var.stack_name}-vpc"
  })
}

resource "aws_subnet" "private" {
  count             = var.create_vpc ? 2 : 0
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = merge(var.tags, {
    Name = "${var.stack_name}-private-${count.index + 1}"
  })
}

resource "aws_internet_gateway" "main" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  
  tags = merge(var.tags, {
    Name = "${var.stack_name}-igw"
  })
}

resource "aws_eip" "nat" {
  count  = var.create_vpc ? 1 : 0
  domain = "vpc"
  
  tags = merge(var.tags, {
    Name = "${var.stack_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  count         = var.create_vpc ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  
  tags = merge(var.tags, {
    Name = "${var.stack_name}-nat"
  })
}

resource "aws_subnet" "public" {
  count                   = var.create_vpc ? 1 : 0
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 10)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  
  tags = merge(var.tags, {
    Name = "${var.stack_name}-public"
  })
}

resource "aws_route_table" "private" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }
  
  tags = merge(var.tags, {
    Name = "${var.stack_name}-private-rt"
  })
}

resource "aws_route_table" "public" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }
  
  tags = merge(var.tags, {
    Name = "${var.stack_name}-public-rt"
  })
}

resource "aws_route_table_association" "private" {
  count          = var.create_vpc ? 2 : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_route_table_association" "public" {
  count          = var.create_vpc ? 1 : 0
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_security_group" "lambda" {
  count  = var.create_vpc ? 1 : 0
  name   = "${var.stack_name}-lambda-sg"
  vpc_id = aws_vpc.main[0].id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.tags, {
    Name = "${var.stack_name}-lambda-sg"
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Lambda function for identity provider
resource "aws_lambda_function" "identity_provider" {
  filename         = var.lambda_zip_path
  function_name    = "${var.stack_name}-identity-provider"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      LOG_LEVEL                = var.log_level
      USER_NAME_DELIMITER      = var.user_name_delimiter
      USERS_TABLE             = var.users_table_name
      IDENTITY_PROVIDERS_TABLE = var.identity_providers_table_name
    }
  }

  dynamic "vpc_config" {
    for_each = var.use_vpc ? [1] : []
    content {
      subnet_ids = var.create_vpc ? aws_subnet.private[*].id : split(",", var.subnets)
      security_group_ids = var.create_vpc ? [aws_security_group.lambda[0].id] : split(",", var.security_groups)
    }
  }

  tracing_config {
    mode = var.enable_tracing ? "Active" : "PassThrough"
  }

  tags = var.tags
}

# API Gateway for identity provider
resource "aws_api_gateway_rest_api" "identity_provider" {
  count = var.provision_api ? 1 : 0
  name  = "${var.stack_name}-identity-provider-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

resource "aws_api_gateway_resource" "servers" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  parent_id   = aws_api_gateway_rest_api.identity_provider[0].root_resource_id
  path_part   = "servers"
}

resource "aws_api_gateway_resource" "server_id" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  parent_id   = aws_api_gateway_resource.servers[0].id
  path_part   = "{serverId}"
}

resource "aws_api_gateway_resource" "users" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  parent_id   = aws_api_gateway_resource.server_id[0].id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "username" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  parent_id   = aws_api_gateway_resource.users[0].id
  path_part   = "{username}"
}

resource "aws_api_gateway_resource" "config" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  parent_id   = aws_api_gateway_resource.username[0].id
  path_part   = "config"
}

resource "aws_api_gateway_method" "get_user_config" {
  count         = var.provision_api ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.identity_provider[0].id
  resource_id   = aws_api_gateway_resource.config[0].id
  http_method   = "GET"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "lambda" {
  count       = var.provision_api ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.identity_provider[0].id
  resource_id = aws_api_gateway_resource.config[0].id
  http_method = aws_api_gateway_method.get_user_config[0].http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.identity_provider.invoke_arn
}

# DynamoDB tables - these should be created externally and passed via variables
# No table creation in the module

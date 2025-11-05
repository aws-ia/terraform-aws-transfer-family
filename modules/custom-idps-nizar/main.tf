data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#########################################
# S3 bucket to store CodeBuild artifacts 
#########################################

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.stack_name}-custom-idp-codebuild-artifacts-bucket-${data.aws_caller_identity.current.account_id}"
  tags   = var.tags
}

######################################################################################
# CodeBuild project to download code from Tookit Git repo and publish artifacts to S3
######################################################################################

resource "aws_codebuild_project" "build" {
  name          = "${var.stack_name}-custom-idp-codebuild-project"
  description   = "Build Lambda artifacts for Transfer Family Custom IdP"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 30
  
  artifacts {
    type = "S3"
    location = aws_s3_bucket.artifacts.bucket
    path = ""
    packaging = "ZIP"
  }
  
  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
    
    environment_variable {
      name  = "ARTIFACTS_BUCKET"
      value = aws_s3_bucket.artifacts.bucket
    }
    
    environment_variable {
      name  = "FUNCTION_ARTIFACT_KEY"
      value = var.function_artifact_key
    }
    
    environment_variable {
      name  = "LAYER_ARTIFACT_KEY"
      value = var.layer_artifact_key
    }
    
    environment_variable {
      name  = "GITHUB_REPO"
      value = var.github_repository_url
    }
    
    environment_variable {
      name  = "GITHUB_BRANCH"
      value = var.github_branch
    }
    
    environment_variable {
      name  = "SOLUTION_PATH"
      value = var.solution_path
    }
  }
  
  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/buildspec.yml")
  }
  
  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild_log_group.name
    }
  }
  
  tags = var.tags
}

###########################################
# CloudWatch Log group for CodeBuild logs 
###########################################

resource "aws_cloudwatch_log_group" "codebuild_log_group" {
  name              = "/aws/codebuild/${var.stack_name}-custom-idp-codebuild-project"
  retention_in_days = 7
  tags              = var.tags
}

########################################
# Trigger CodeBuild to create artifacts
########################################

resource "null_resource" "build_trigger" {
  triggers = {
    force_build        = var.force_build ? timestamp() : "false"
    codebuild_project  = aws_codebuild_project.build.id
    github_repo        = var.github_repository_url
    github_branch      = var.github_branch
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      BUILD_ID=$(aws codebuild start-build \
        --project-name ${aws_codebuild_project.build.name} \
        --query 'build.id' \
        --output text)
      
      echo "CodeBuild started: $BUILD_ID"
      
      # Wait for build to complete
      while true; do
        BUILD_STATUS=$(aws codebuild batch-get-builds \
          --ids $BUILD_ID \
          --query 'builds[0].buildStatus' \
          --output text)
        
        if [ "$BUILD_STATUS" == "SUCCEEDED" ]; then
          echo "Build succeeded"
          exit 0
        elif [ "$BUILD_STATUS" == "FAILED" ] || [ "$BUILD_STATUS" == "FAULT" ] || [ "$BUILD_STATUS" == "TIMED_OUT" ] || [ "$BUILD_STATUS" == "STOPPED" ]; then
          echo "Build failed with status: $BUILD_STATUS"
          exit 1
        fi
        
        echo "Build status: $BUILD_STATUS, waiting..."
        sleep 10
      done
    EOT
  }
  
  depends_on = [
    aws_codebuild_project.build,
    aws_s3_bucket.artifacts
  ]
}

######################################
# IAM Role for CodeBuild
######################################

resource "aws_iam_role" "codebuild_role" {
  name = "${var.stack_name}-custom-idp-codebuild-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  
  tags = var.tags
}

######################################
# IAM policy for CodeBuild role
######################################

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.stack_name}-custom-idp-codebuild-policy"
  role        = aws_iam_role.codebuild_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.codebuild_log_group.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })
}

##############################################
# Lambda layer for Transfer Family Custom IdP
##############################################

resource "aws_lambda_layer_version" "idp_handler_layer" {
  layer_name          = "${var.stack_name}-idp-handler-layer"
  s3_bucket           = aws_s3_bucket.artifacts.bucket
  s3_key              = var.layer_artifact_key
  compatible_runtimes = [var.lambda_runtime]
  description         = "Dependencies for Transfer Family Custom IdP"
  
  lifecycle {
    replace_triggered_by = [null_resource.build_trigger]
  }
  
  depends_on = [null_resource.build_trigger]
}

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
  function_name    = "${var.stack_name}-identity-provider"
  role            = aws_iam_role.lambda_role.arn
  handler         = "app.lambda_handler"
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  layers          = [aws_lambda_layer_version.idp_handler_layer.arn]
  s3_bucket       = aws_s3_bucket.artifacts.bucket
  s3_key          = var.function_artifact_key

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

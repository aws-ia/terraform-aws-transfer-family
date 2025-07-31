#
# AWS Transfer Family Custom IdP Terraform Module
#
# This module provides a complete Terraform implementation of the AWS Transfer Family
# Custom Identity Provider solution, replacing the original SAM template with native
# Terraform resources while maintaining full feature parity.
#

#
# Lambda Layer with Python Dependencies
#
resource "aws_lambda_layer_version" "idp_handler_layer" {
  filename                 = "${path.module}/lambda-layer.zip"
  layer_name              = "${var.name_prefix}-idp-handler-layer"
  compatible_runtimes     = ["python3.11"]
  source_code_hash        = filebase64sha256("${path.module}/lambda-layer.zip")
  
  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [null_resource.build_lambda_layer]
}

# Build Lambda layer with Python dependencies
resource "null_resource" "build_lambda_layer" {
  triggers = {
    requirements_hash = filemd5("${path.module}/requirements.txt")
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/layer/python
      pip install -r ${path.module}/requirements.txt -t ${path.module}/layer/python --no-cache-dir
      cd ${path.module}/layer && zip -r ../lambda-layer.zip python/
      rm -rf ${path.module}/layer
    EOT
  }
}

#
# Lambda Function Source Code Packaging
#
data "archive_file" "lambda_function" {
  type        = "zip"
  output_path = "${path.module}/lambda-function.zip"
  source_dir  = "${path.module}/lambda-src"
  excludes    = ["__pycache__", "*.pyc", ".DS_Store", "*.pyo"]
}

#
# Lambda Function
#
resource "aws_lambda_function" "idp_handler" {
  filename         = data.archive_file.lambda_function.output_path
  function_name    = "${var.name_prefix}-idp-handler"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "app.lambda_handler"
  runtime         = "python3.11"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  layers          = [aws_lambda_layer_version.idp_handler_layer.arn]
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  
  dynamic "vpc_config" {
    for_each = local.vpc_config
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  
  environment {
    variables = local.lambda_environment_variables
  }
  
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }
  
  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_vpc_execution
  ]
  
  tags = local.common_tags
}

#
# Lambda Permission for AWS Transfer Family
#
resource "aws_lambda_permission" "allow_transfer" {
  statement_id  = "AllowExecutionFromTransfer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.idp_handler.function_name
  principal     = "transfer.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

#
# DynamoDB Users Table
#
resource "aws_dynamodb_table" "users" {
  count          = var.existing_users_table_name == null ? 1 : 0
  name           = "${var.name_prefix}-users"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "user"
  range_key      = "identity_provider_key"
  
  attribute {
    name = "user"
    type = "S"
  }
  
  attribute {
    name = "identity_provider_key"
    type = "S"
  }
  
  server_side_encryption {
    enabled     = true
    kms_key_id  = var.kms_key_id
  }
  
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  
  tags = local.common_tags
}

#
# DynamoDB Identity Providers Table
#
resource "aws_dynamodb_table" "identity_providers" {
  count          = var.existing_identity_providers_table_name == null ? 1 : 0
  name           = "${var.name_prefix}-identity-providers"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "provider"
  
  attribute {
    name = "provider"
    type = "S"
  }
  
  server_side_encryption {
    enabled     = true
    kms_key_id  = var.kms_key_id
  }
  
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
  
  tags = local.common_tags
}

# IAM Roles and Policies (will be implemented in task 5)
# API Gateway (will be implemented in task 6)
#
# CloudWatch Log Group (basic implementation for Lambda dependency)
#
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.name_prefix}-idp-handler"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.kms_key_id
  
  tags = local.common_tags
}

#
# Basic IAM Role for Lambda (will be expanded in task 5)
#
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.name_prefix}-lambda-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# Basic Lambda execution policy attachments
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count      = var.use_vpc ? 1 : 0
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

#
# DynamoDB Access Policy for Lambda
#
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.name_prefix}-dynamodb-access"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = [
          local.users_table_arn,
          local.identity_providers_table_arn
        ]
      }
    ]
  })
}

#
# Conditional Secrets Manager Access Policy
#
resource "aws_iam_role_policy" "secrets_manager_access" {
  count = var.enable_secrets_manager_permissions ? 1 : 0
  name  = "${var.name_prefix}-secrets-manager-access"
  role  = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:*"
      }
    ]
  })
}

#
# Optional X-Ray Tracing Permissions
#
resource "aws_iam_role_policy" "xray_tracing" {
  count = var.enable_xray_tracing ? 1 : 0
  name  = "${var.name_prefix}-xray-tracing"
  role  = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

#
# AWS Transfer DescribeServer Permissions
#
resource "aws_iam_role_policy" "transfer_describe" {
  name = "${var.name_prefix}-transfer-describe"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "transfer:DescribeServer"
        ]
        Resource = "arn:aws:transfer:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:server/*"
      }
    ]
  })
}

#
# Optional API Gateway Integration
#

#
# API Gateway REST API
#
resource "aws_api_gateway_rest_api" "custom_idp_api" {
  count       = var.enable_api_gateway ? 1 : 0
  name        = "${var.name_prefix}-custom-idp-api"
  description = "Custom Identity Provider API for AWS Transfer Family"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  
  tags = local.common_tags
}

#
# API Gateway Resource Hierarchy for Transfer Integration
# Path: /servers/{serverId}/users/{username}/config
#

resource "aws_api_gateway_resource" "servers" {
  count       = var.enable_api_gateway ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.custom_idp_api[0].id
  parent_id   = aws_api_gateway_rest_api.custom_idp_api[0].root_resource_id
  path_part   = "servers"
}

resource "aws_api_gateway_resource" "server_id" {
  count       = var.enable_api_gateway ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.custom_idp_api[0].id
  parent_id   = aws_api_gateway_resource.servers[0].id
  path_part   = "{serverId}"
}

resource "aws_api_gateway_resource" "users" {
  count       = var.enable_api_gateway ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.custom_idp_api[0].id
  parent_id   = aws_api_gateway_resource.server_id[0].id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "username" {
  count       = var.enable_api_gateway ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.custom_idp_api[0].id
  parent_id   = aws_api_gateway_resource.users[0].id
  path_part   = "{username}"
}

resource "aws_api_gateway_resource" "config" {
  count       = var.enable_api_gateway ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.custom_idp_api[0].id
  parent_id   = aws_api_gateway_resource.username[0].id
  path_part   = "config"
}

#
# API Gateway Method and Lambda Integration
#
resource "aws_api_gateway_method" "get_user_config" {
  count         = var.enable_api_gateway ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.custom_idp_api[0].id
  resource_id   = aws_api_gateway_resource.config[0].id
  http_method   = "GET"
  authorization = "AWS_IAM"
  
  request_parameters = {
    "method.request.header.PasswordBase64" = false
    "method.request.querystring.protocol"  = false
    "method.request.querystring.sourceIp"  = false
  }
}

resource "aws_api_gateway_integration" "lambda_integration" {
  count                   = var.enable_api_gateway ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.custom_idp_api[0].id
  resource_id             = aws_api_gateway_resource.config[0].id
  http_method             = aws_api_gateway_method.get_user_config[0].http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.idp_handler.invoke_arn
  
  request_templates = {
    "application/json" = jsonencode({
      username  = "$util.urlDecode($input.params('username'))"
      password  = "$util.escapeJavaScript($util.base64Decode($input.params('PasswordBase64'))).replaceAll(\"\\\\'\",\"'\")"
      protocol  = "$input.params('protocol')"
      serverId  = "$input.params('serverId')"
      sourceIp  = "$input.params('sourceIp')"
    })
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  count       = var.enable_api_gateway ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.custom_idp_api[0].id
  resource_id = aws_api_gateway_resource.config[0].id
  http_method = aws_api_gateway_method.get_user_config[0].http_method
  status_code = "200"
  
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "lambda_integration_response" {
  count       = var.enable_api_gateway ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.custom_idp_api[0].id
  resource_id = aws_api_gateway_resource.config[0].id
  http_method = aws_api_gateway_method.get_user_config[0].http_method
  status_code = aws_api_gateway_method_response.response_200[0].status_code
  
  depends_on = [aws_api_gateway_integration.lambda_integration]
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "allow_api_gateway" {
  count         = var.enable_api_gateway ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.idp_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.custom_idp_api[0].execution_arn}/*/*"
}

#
# API Gateway Deployment and Stage
#
resource "aws_api_gateway_deployment" "api_deployment" {
  count       = var.enable_api_gateway ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.custom_idp_api[0].id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.servers[0].id,
      aws_api_gateway_resource.server_id[0].id,
      aws_api_gateway_resource.users[0].id,
      aws_api_gateway_resource.username[0].id,
      aws_api_gateway_resource.config[0].id,
      aws_api_gateway_method.get_user_config[0].id,
      aws_api_gateway_integration.lambda_integration[0].id,
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [
    aws_api_gateway_method.get_user_config,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method_response.response_200,
    aws_api_gateway_integration_response.lambda_integration_response
  ]
}

resource "aws_api_gateway_stage" "api_stage" {
  count         = var.enable_api_gateway ? 1 : 0
  deployment_id = aws_api_gateway_deployment.api_deployment[0].id
  rest_api_id   = aws_api_gateway_rest_api.custom_idp_api[0].id
  stage_name    = "prod"
  
  xray_tracing_enabled = var.enable_xray_tracing
  
  tags = local.common_tags
}

#
# API Gateway IAM Role for AWS Transfer Family
#
resource "aws_iam_role" "api_gateway_execution_role" {
  count = var.enable_api_gateway ? 1 : 0
  name  = "${var.name_prefix}-api-gateway-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:sourceArn" = "arn:aws:transfer:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:server/*"
          }
        }
      }
    ]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy" "api_gateway_invoke_policy" {
  count = var.enable_api_gateway ? 1 : 0
  name  = "${var.name_prefix}-api-gateway-invoke"
  role  = aws_iam_role.api_gateway_execution_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "execute-api:Invoke"
        ]
        Resource = "${aws_api_gateway_rest_api.custom_idp_api[0].execution_arn}/prod/GET/*"
      },
      {
        Effect = "Allow"
        Action = [
          "apigateway:GET"
        ]
        Resource = "*"
      }
    ]
  })
}
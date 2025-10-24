data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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
      subnet_ids         = split(",", var.subnets)
      security_group_ids = split(",", var.security_groups)
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

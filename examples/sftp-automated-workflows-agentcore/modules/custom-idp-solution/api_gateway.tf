resource "aws_api_gateway_rest_api" "this" {
  count = var.provision_api ? 1 : 0

  name        = "${var.name_prefix}-api"
  description = "Custom Identity Provider API for AWS Transfer Family"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "servers" {
  count = var.provision_api ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_rest_api.this[0].root_resource_id
  path_part   = "servers"
}

resource "aws_api_gateway_resource" "server_id" {
  count = var.provision_api ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.servers[0].id
  path_part   = "{serverId}"
}

resource "aws_api_gateway_resource" "users" {
  count = var.provision_api ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.server_id[0].id
  path_part   = "users"
}

resource "aws_api_gateway_resource" "username" {
  count = var.provision_api ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.users[0].id
  path_part   = "{username}"
}

resource "aws_api_gateway_resource" "config" {
  count = var.provision_api ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id
  parent_id   = aws_api_gateway_resource.username[0].id
  path_part   = "config"
}

resource "aws_api_gateway_method" "get" {
  count = var.provision_api ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  resource_id   = aws_api_gateway_resource.config[0].id
  http_method   = "GET"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "lambda" {
  count = var.provision_api ? 1 : 0

  rest_api_id             = aws_api_gateway_rest_api.this[0].id
  resource_id             = aws_api_gateway_resource.config[0].id
  http_method             = aws_api_gateway_method.get[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.handler.invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  count = var.provision_api ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.this[0].id

  depends_on = [
    aws_api_gateway_integration.lambda
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  count = var.provision_api ? 1 : 0

  deployment_id = aws_api_gateway_deployment.this[0].id
  rest_api_id   = aws_api_gateway_rest_api.this[0].id
  stage_name    = "prod"

  tags = local.common_tags
}

resource "aws_lambda_permission" "api_gateway" {
  count = var.provision_api ? 1 : 0

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this[0].execution_arn}/*/*"
}

locals {
  is_directory_service = var.identity_provider.type == "AWS_DIRECTORY_SERVICE"
  is_lambda            = var.identity_provider.type == "AWS_LAMBDA"
  is_api_gateway       = var.identity_provider.type == "API_GATEWAY"
}

resource "aws_transfer_server" "transfer_server" {
  identity_provider_type    = var.identity_provider.type
  domain                    = var.transfer_server_base.domain
  protocols                 = var.transfer_server_base.protocols
  endpoint_type             = var.transfer_server_base.endpoint_type

  # API Gateway specific configurations
  url              = local.is_api_gateway ? var.identity_provider.url : null
  invocation_role  = local.is_api_gateway ? var.identity_provider.invocation_role : null

  # For AWS Directory Service
  directory_id = local.is_directory_service ? var.identity_provider.directory_id : null

  # For Lambda
  function = local.is_lambda ? var.identity_provider.function_name : null

  tags = {
    Name        = "transfer-server"
    Environment = var.transfer_server_base.environment
  }
}
# locals {
#   is_directory_service = var.identity_provider.type == "AWS_DIRECTORY_SERVICE"
#   is_lambda            = var.identity_provider.type == "AWS_LAMBDA"
#   is_api_gateway       = var.identity_provider.type == "API_GATEWAY"
# }

resource "aws_transfer_server" "transfer_server" {
  identity_provider_type    = var.identity_provider
  domain                    = var.domain
  protocols                 = var.protocols
  endpoint_type             = var.endpoint_type
  security_policy_name      = var.security_policy_name
  logging_role              = var.enable_logging ? aws_iam_role.logging[0].arn : null

  # # API Gateway specific configurations
  # url              = local.is_api_gateway ? var.identity_provider.url : null
  # invocation_role  = local.is_api_gateway ? var.identity_provider.invocation_role : null

  # # For AWS Directory Service
  # directory_id = local.is_directory_service ? var.identity_provider.directory_id : null

  # # For Lambda
  # function = local.is_lambda ? var.identity_provider.function_name : null

  tags = merge(
    var.tags,
    {
      Name = var.server_name
    }
  )
}
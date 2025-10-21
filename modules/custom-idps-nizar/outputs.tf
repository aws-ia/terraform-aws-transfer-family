output "lambda_function_arn" {
  description = "Lambda function ARN for identity provider"
  value       = aws_lambda_function.identity_provider.arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.identity_provider.function_name
}

output "transfer_invocation_role_arn" {
  description = "Transfer Family invocation role ARN"
  value       = aws_iam_role.transfer_invocation_role.arn
}

output "api_gateway_url" {
  description = "API Gateway URL (if provisioned)"
  value       = var.provision_api ? "https://${aws_api_gateway_rest_api.identity_provider[0].id}.execute-api.${data.aws_region.current.name}.amazonaws.com" : null
}

output "users_table_name" {
  description = "DynamoDB users table name"
  value       = var.users_table_name != "" ? var.users_table_name : try(aws_dynamodb_table.users[0].name, null)
}

output "identity_providers_table_name" {
  description = "DynamoDB identity providers table name"
  value       = var.identity_providers_table_name != "" ? var.identity_providers_table_name : try(aws_dynamodb_table.identity_providers[0].name, null)
}

output "users_table_hash_key" {
  description = "DynamoDB users table hash key"
  value       = "Username"
}

output "identity_providers_table_hash_key" {
  description = "DynamoDB identity providers table hash key"
  value       = "ServerId"
}

output "api_gateway_role_arn" {
  description = "API Gateway invocation role ARN"
  value       = aws_iam_role.transfer_invocation_role.arn
}

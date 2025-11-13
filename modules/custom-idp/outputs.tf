output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.sftp_users.id
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.sftp_client.id
}

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
  value       = var.use_api_gateway ? aws_iam_role.transfer_api_gateway_role[0].arn : aws_iam_role.transfer_invocation_role[0].arn
}

output "api_gateway_url" {
  description = "API Gateway URL (if provisioned)"
  value       = var.use_api_gateway ? "https://${aws_api_gateway_rest_api.identity_provider[0].id}.execute-api.${data.aws_region.current.name}.amazonaws.com/prod" : null
}

output "users_table_name" {
  description = "DynamoDB users table name"
  value       = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  description = "DynamoDB users table ARN"
  value       = aws_dynamodb_table.users.arn
}

output "identity_providers_table_name" {
  description = "DynamoDB identity providers table name"
  value       = aws_dynamodb_table.identity_providers.name
}

output "identity_providers_table_arn" {
  description = "DynamoDB identity providers table ARN"
  value       = aws_dynamodb_table.identity_providers.arn
}

output "users_table_hash_key" {
  description = "DynamoDB users table hash key"
  value       = "Username"
}

output "identity_providers_table_hash_key" {
  description = "DynamoDB identity providers table hash key"
  value       = "ServerId"
}



output "vpc_id" {
  description = "ID of the created VPC"
  value       = var.create_vpc ? aws_vpc.main[0].id : null
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = var.create_vpc ? aws_subnet.private[*].id : []
}

output "security_group_id" {
  description = "ID of the Lambda security group"
  value       = var.create_vpc ? aws_security_group.lambda[0].id : null
}

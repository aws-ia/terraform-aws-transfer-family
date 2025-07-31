# Lambda Function Outputs
output "lambda_function_arn" {
  description = "ARN of the IdP handler Lambda function"
  value       = aws_lambda_function.idp_handler.arn
}

output "lambda_function_name" {
  description = "Name of the IdP handler Lambda function"
  value       = aws_lambda_function.idp_handler.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the IdP handler Lambda function"
  value       = aws_lambda_function.idp_handler.invoke_arn
}

output "lambda_layer_arn" {
  description = "ARN of the Lambda layer"
  value       = aws_lambda_layer_version.idp_handler_layer.arn
}

# DynamoDB Table Outputs
output "users_table_name" {
  description = "Name of the users DynamoDB table"
  value       = local.users_table_name
}

output "users_table_arn" {
  description = "ARN of the users DynamoDB table"
  value       = local.users_table_arn
}

output "identity_providers_table_name" {
  description = "Name of the identity providers DynamoDB table"
  value       = local.identity_providers_table_name
}

output "identity_providers_table_arn" {
  description = "ARN of the identity providers DynamoDB table"
  value       = local.identity_providers_table_arn
}

# API Gateway Outputs (conditional)
output "api_gateway_url" {
  description = "URL of the API Gateway (if enabled)"
  value       = var.enable_api_gateway ? aws_api_gateway_deployment.api_deployment[0].invoke_url : null
}

output "api_gateway_execution_role_arn" {
  description = "ARN of the API Gateway execution role (if enabled)"
  value       = var.enable_api_gateway ? aws_iam_role.api_gateway_execution_role[0].arn : null
}

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC used by Lambda function"
  value       = var.vpc_id
}

output "subnet_ids" {
  description = "List of subnet IDs used by Lambda function"
  value       = var.subnet_ids
}

output "security_group_ids" {
  description = "List of security group IDs used by Lambda function"
  value       = var.security_group_ids
}

# CloudWatch Outputs
output "lambda_log_group_name" {
  description = "Name of the Lambda function CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "lambda_log_group_arn" {
  description = "ARN of the Lambda function CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}
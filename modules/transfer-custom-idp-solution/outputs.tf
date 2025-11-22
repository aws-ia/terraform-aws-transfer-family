output "lambda_function_arn" {
  description = "Lambda function ARN for identity provider"
  value       = aws_lambda_function.identity_provider.arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.identity_provider.function_name
}

output "lambda_function_qualified_arn" {
  description = "Qualified ARN of the Lambda function"
  value       = aws_lambda_function.identity_provider.qualified_arn
}

output "transfer_invocation_role_arn" {
  description = "Transfer Family invocation role ARN"
  value       = var.provision_api ? aws_iam_role.transfer_api_gateway_role[0].arn : aws_iam_role.transfer_invocation_role[0].arn
}

output "api_gateway_url" {
  description = "API Gateway URL (if provisioned)"
  value       = var.provision_api ? "https://${aws_api_gateway_rest_api.identity_provider[0].id}.execute-api.${data.aws_region.current.name}.amazonaws.com/prod" : null
}

output "api_gateway_role_arn" {
  description = "ARN of the API Gateway IAM role (if provisioned)"
  value       = var.provision_api ? aws_iam_role.transfer_api_gateway_role[0].arn : null
}

output "artifacts_bucket_name" {
  description = "Name of the S3 bucket storing the build artifacts"
  value       = aws_s3_bucket.artifacts.id
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project that was used to build the artifacts"
  value       = aws_codebuild_project.build.name
}

output "users_table_name" {
  description = "DynamoDB users table name"
  value       = var.users_table_name == "" ? aws_dynamodb_table.users[0].name : var.users_table_name
}

output "users_table_arn" {
  description = "DynamoDB users table ARN"
  value       = var.users_table_name == "" ? aws_dynamodb_table.users[0].arn : "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.users_table_name}"
}

output "identity_providers_table_name" {
  description = "DynamoDB identity providers table name"
  value       = var.identity_providers_table_name == "" ? aws_dynamodb_table.identity_providers[0].name : var.identity_providers_table_name
}

output "identity_providers_table_arn" {
  description = "DynamoDB identity providers table ARN"
  value       = var.identity_providers_table_name == "" ? aws_dynamodb_table.identity_providers[0].arn : "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.identity_providers_table_name}"
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

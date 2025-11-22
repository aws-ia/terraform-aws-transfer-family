output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.handler.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.handler.function_name
}

output "lambda_function_qualified_arn" {
  description = "Qualified ARN of the Lambda function"
  value       = aws_lambda_function.handler.qualified_arn
}

output "users_table_name" {
  description = "Name of the DynamoDB users table"
  value       = local.users_table
}

output "users_table_arn" {
  description = "ARN of the DynamoDB users table"
  value       = var.users_table_name == "" ? aws_dynamodb_table.users[0].arn : "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.users_table_name}"
}

output "identity_providers_table_name" {
  description = "Name of the DynamoDB identity providers table"
  value       = local.providers_table
}

output "identity_providers_table_arn" {
  description = "ARN of the DynamoDB identity providers table"
  value       = var.identity_providers_table_name == "" ? aws_dynamodb_table.identity_providers[0].arn : "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.identity_providers_table_name}"
}

output "api_gateway_url" {
  description = "URL of the API Gateway (if provisioned)"
  value       = var.provision_api ? aws_api_gateway_stage.prod[0].invoke_url : null
}

output "api_gateway_role_arn" {
  description = "ARN of the API Gateway IAM role (if provisioned)"
  value       = var.provision_api ? aws_iam_role.api_gateway[0].arn : null
}

output "vpc_id" {
  description = "ID of the VPC (if created)"
  value       = var.create_vpc ? aws_vpc.main[0].id : null
}

output "private_subnet_ids" {
  description = "IDs of private subnets (if VPC created)"
  value       = var.create_vpc ? aws_subnet.private[*].id : null
}

output "artifacts_bucket_name" {
  description = "Name of the S3 bucket storing the build artifacts"
  value       = aws_s3_bucket.artifacts.id
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project that was used to build the artifacts"
  value       = aws_codebuild_project.build.name
}

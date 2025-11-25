output "server_id" {
  description = "The ID of the created Transfer Family server"
  value       = module.transfer_server.server_id
}

output "server_endpoint" {
  description = "The endpoint of the created Transfer Family server"
  value       = module.transfer_server.server_endpoint
}

output "lambda_function_arn" {
  description = "Custom IDP Lambda function ARN"
  value       = module.custom_idp.lambda_function_arn
}

output "lambda_function_name" {
  description = "Custom IDP Lambda function name"
  value       = module.custom_idp.lambda_function_name
}

output "users_table_name" {
  description = "DynamoDB users table name"
  value       = module.custom_idp.users_table_name
}

output "identity_providers_table_name" {
  description = "DynamoDB identity providers table name"
  value       = module.custom_idp.identity_providers_table_name
}

output "transfer_session_role_arn" {
  description = "ARN of the Transfer Family session role"
  value       = aws_iam_role.transfer_session.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket used for Transfer Family"
  value       = module.s3_bucket.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket used for Transfer Family"
  value       = module.s3_bucket.s3_bucket_arn
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito user pool (created or existing)"
  value       = var.existing_cognito_user_pool_id != null ? var.existing_cognito_user_pool_id : aws_cognito_user_pool.transfer_users[0].id
}

output "cognito_user_pool_name" {
  description = "Name of the Cognito user pool (only available when created by this module)"
  value       = var.existing_cognito_user_pool_id != null ? null : aws_cognito_user_pool.transfer_users[0].name
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito user pool client (created or existing)"
  value       = var.existing_cognito_user_pool_id != null ? var.existing_cognito_user_pool_client_id : aws_cognito_user_pool_client.transfer_client[0].id
}

output "cognito_username" {
  description = "Username of the created Cognito user (only when pool is created)"
  value       = var.existing_cognito_user_pool_id != null ? null : aws_cognito_user.transfer_user[0].username
}

output "cognito_user_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Cognito user password (only when pool is created)"
  value       = var.existing_cognito_user_pool_id != null ? null : aws_secretsmanager_secret.cognito_user_password[0].arn
}

output "cognito_user_password_secret_name" {
  description = "Name of the Secrets Manager secret containing the Cognito user password (only when pool is created)"
  value       = var.existing_cognito_user_pool_id != null ? null : aws_secretsmanager_secret.cognito_user_password[0].name
}
output "transfer_server_id" {
  description = "ID of the Transfer Family server"
  value       = aws_transfer_server.sftp_server.id
}

output "transfer_server_endpoint" {
  description = "Endpoint of the Transfer Family server"
  value       = aws_transfer_server.sftp_server.endpoint
}

output "api_gateway_url" {
  description = "API Gateway URL used by Transfer Family"
  value       = module.custom_idp.api_gateway_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.custom_idp.cognito_user_pool_id
}

output "s3_bucket_name" {
  description = "S3 bucket for SFTP file storage"
  value       = aws_s3_bucket.sftp_storage.bucket
}

output "dynamodb_users_table" {
  description = "DynamoDB table for user configuration"
  value       = module.custom_idp.users_table_name
}

output "cognito_user_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Cognito user password"
  value       = aws_secretsmanager_secret.cognito_user_password.arn
}

output "cognito_username" {
  description = "Cognito username for SFTP login"
  value       = var.cognito_username
}

output "retrieve_password_command" {
  description = "AWS CLI command to retrieve the Cognito user password"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.cognito_user_password.arn} --query SecretString --output text | jq -r '.password'"
}

output "test_connection_command" {
  description = "Command to test SFTP connection (retrieve password first using retrieve_password_command)"
  value       = "sftp ${var.cognito_username}@@user_pool@${aws_transfer_server.sftp_server.endpoint}"
}
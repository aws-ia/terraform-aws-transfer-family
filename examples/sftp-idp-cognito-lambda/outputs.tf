output "transfer_server_id" {
  description = "Transfer server ID"
  value       = aws_transfer_server.sftp.id
}

output "transfer_server_endpoint" {
  description = "Transfer server endpoint"
  value       = aws_transfer_server.sftp.endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket for file transfers"
  value       = aws_s3_bucket.transfer_files.bucket
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.transfer_users.id
}

output "lambda_function_arn" {
  description = "Custom IDP Lambda function ARN"
  value       = module.custom_idp.lambda_function_arn
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
  value       = "sftp ${var.cognito_username}@@domain2019.local@${aws_transfer_server.sftp.endpoint}"
}
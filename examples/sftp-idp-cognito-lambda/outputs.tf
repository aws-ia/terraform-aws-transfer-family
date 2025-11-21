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

output "test_connection_command" {
  description = "Command to test SFTP connection"
  value       = "sftp $default$@${aws_transfer_server.sftp.endpoint}"
}
output "transfer_server_id" {
  description = "Transfer server ID"
  value       = aws_transfer_server.sftp.id
}

output "transfer_server_endpoint" {
  description = "Transfer server endpoint"
  value       = aws_transfer_server.sftp.endpoint
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.transfer_users.id
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.transfer_client.id
}

output "s3_bucket_name" {
  description = "S3 bucket for SFTP files"
  value       = aws_s3_bucket.sftp_bucket.bucket
}

output "test_username" {
  description = "Test username for SFTP login"
  value       = var.test_username
}

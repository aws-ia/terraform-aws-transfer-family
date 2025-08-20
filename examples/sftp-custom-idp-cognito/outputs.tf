output "transfer_server_endpoint" {
  description = "Transfer server endpoint for SFTP connections"
  value       = module.transfer_server.server_endpoint
}

output "transfer_server_id" {
  description = "Transfer server ID"
  value       = module.transfer_server.server_id
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
  description = "S3 bucket name for file storage"
  value       = aws_s3_bucket.transfer_storage.id
}

output "test_user_credentials" {
  description = "Test user credentials for SFTP connection"
  value = {
    username = var.test_username
    password = var.test_user_password
    format   = "${var.test_username}@@cognito"
  }
  sensitive = true
}

output "sftp_connection_command" {
  description = "SFTP connection command for testing"
  value       = "sftp '${var.test_username}@@cognito'@${module.transfer_server.server_endpoint}"
}
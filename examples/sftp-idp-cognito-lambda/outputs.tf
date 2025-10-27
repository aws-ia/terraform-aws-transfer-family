output "sftp_server_endpoint" {
  description = "SFTP server endpoint"
  value       = module.transfer_server.server_endpoint
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.sftp_users.id
}

output "test_users" {
  description = "Test users for SFTP connection"
  value = {
    testuser1 = {
      username = "testuser1@@cognito"
      password = "TempPass123!"
    }
    testuser2 = {
      username = "testuser2@@cognito" 
      password = "TempPass123!"
    }
  }
}

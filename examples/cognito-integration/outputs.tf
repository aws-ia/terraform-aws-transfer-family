output "transfer_server_endpoint" {
  description = "The endpoint of the Transfer Family server"
  value       = module.transfer_server.server_endpoint
}

output "transfer_server_id" {
  description = "The ID of the Transfer Family server"
  value       = module.transfer_server.server_id
}

output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.sftp_users.id
}

output "cognito_client_id" {
  description = "The ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.sftp_client.id
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket for SFTP storage"
  value       = aws_s3_bucket.sftp_bucket.bucket
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB configuration table"
  value       = aws_dynamodb_table.transfer_config.name
}

output "test_users" {
  description = "List of test users created in Cognito"
  value = [
    for i in range(5) : {
      username = "sftpuser${i + 1}"
      password = "Password123!"
      email    = "sftpuser${i + 1}@example.com"
    }
  ]
}

output "sftp_connection_info" {
  description = "Information for connecting to the SFTP server"
  value = {
    endpoint = module.transfer_server.server_endpoint
    port     = 22
    protocol = "SFTP"
    example_command = "sftp sftpuser1@${module.transfer_server.server_endpoint}"
  }
}

output "user_details" {
  description = "Map of users with their details"
  value = {
    for username, user in aws_transfer_user.transfer_users : username => {
      user_arn       = user.arn
      home_directory = user.home_directory
      public_key     = aws_transfer_ssh_key.user_ssh_keys[username].body
    }
  }
}

output "created_users" {
  description = "List of created usernames"
  value       = keys(aws_transfer_user.transfer_users)
}

output "test_user_created" {
  description = "Whether the test user was created"
  value       = var.create_test_user
}

output "test_user_details" {
  description = "Test user details including private key"
  value = var.create_test_user ? {
    username    = "test_user"
    private_key = tls_private_key.test_user_key[0].private_key_pem
    public_key  = tls_private_key.test_user_key[0].public_key_openssh
    secret_arn  = aws_secretsmanager_secret.sftp_private_key[0].arn
  } : null
  sensitive = true
}
output "user_details" {
  description = "Map of users with their details including secret names and ARNs"
  value = {
    for username, user in aws_transfer_user.transfer_users : username => {
      user_arn       = user.arn
      home_directory = user.home_directory
      public_key     = tls_private_key.sftp_keys[username].public_key_openssh
      private_key_secret = {
        arn       = aws_secretsmanager_secret.sftp_private_key[username].arn
        secret_id = aws_secretsmanager_secret.sftp_private_key[username].id
      }
    }
  }
  sensitive = true  # Mark as sensitive since it includes secret references
}

output "created_users" {
  description = "List of created usernames"
  value       = keys(aws_transfer_user.transfer_users)
}
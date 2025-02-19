output "user_details" {
  description = "Map of users with their details including secret names and ARNs"
  value = {
    for username, user in aws_transfer_user.transfer_users : username => {
      user_arn       = user.arn
      home_directory = user.home_directory
      public_key     = module.sftp_keys.public_keys[username]
      private_key_secret = {
        arn       = module.sftp_keys.private_key_secrets[username].arn
        secret_id = module.sftp_keys.private_key_secrets[username].secret_id
      }
    }
  }
  sensitive = true  # Mark as sensitive since it includes secret references
}

output "created_users" {
  description = "List of created usernames"
  value       = keys(aws_transfer_user.transfer_users)
}
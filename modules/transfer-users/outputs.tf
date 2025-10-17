output "user_details" {
  description = "Map of users with their details"
  value = {
    for username, user in aws_transfer_user.transfer_users : username => {
      user_arn       = user.arn
      home_directory = user.home_directory
      public_keys    = [
        for key_id, key_data in local.user_key_combinations :
        aws_transfer_ssh_key.user_ssh_keys[key_id].body
        if key_data.username == username
      ]
    }
  }
}

output "created_users" {
  description = "List of created usernames"
  value       = keys(aws_transfer_user.transfer_users)
}

output "test_user_secret" {
  description = "Test user private key secret"
  value = var.create_test_user ? {
    private_key_secret = {
      arn       = aws_secretsmanager_secret.sftp_private_key[0].arn
      secret_id = aws_secretsmanager_secret.sftp_private_key[0].id
    }
  } : null

  sensitive = true
}
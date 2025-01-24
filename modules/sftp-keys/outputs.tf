output "private_key_secrets" {
  description = "Map of private key secrets"
  value = {
    for username, secret in aws_secretsmanager_secret.sftp_private_key : username => {
      arn        = secret.arn
      secret_id  = secret.id
    }
  }
}

output "public_keys" {
  description = "Map of public keys for each user"
  value = {
    for username, key in tls_private_key.sftp_keys : username => key.public_key_openssh
  }
}
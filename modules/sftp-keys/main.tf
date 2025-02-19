######################################
# Defaults and Locals
######################################

resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 1
}

resource "tls_private_key" "sftp_keys" {
  for_each = { for user in var.users : user.username => user }

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_secretsmanager_secret" "sftp_private_key" {
  for_each = { for user in var.users : user.username => user }

  name        = "sftp-user-private-key-${each.key}-${random_pet.name.id}"
  description = "Private key for the SFTP user"
  kms_key_id  = "alias/aws/secretsmanager"
}

resource "aws_secretsmanager_secret_version" "sftp_private_key_version" {
  for_each = { for user in var.users : user.username => user }

  secret_id     = aws_secretsmanager_secret.sftp_private_key[each.key].id
  secret_string = tls_private_key.sftp_keys[each.key].private_key_pem
}
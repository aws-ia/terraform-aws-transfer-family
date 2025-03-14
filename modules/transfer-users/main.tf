######################################
# Defaults and Locals
######################################

resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 1
}

locals {
  test_user = {
    username          = "test_user"
    home_dir          = "/test_user"
    public_key        = var.create_test_user ? tls_private_key.test_user_key[0].public_key_openssh : ""
    role_arn          = aws_iam_role.sftp_user_role.arn
  }

  # Combine test user with provided users if create_test_user is true
  all_users = var.create_test_user ? concat(var.users, [local.test_user]) : var.users
}

######################################
# IAM Role for SFTP users
######################################
resource "aws_iam_role" "sftp_user_role" {
  name = "${random_pet.name.id}-basic-transfer-user"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "sftp_user_policies" {
  name = "${random_pet.name.id}-sftp-user-policy"
  role = aws_iam_role.sftp_user_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListingOfUserFolder"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn
        ]
      },
      {
        Sid    = "HomeDirObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ]
        Resource = [
          "${var.s3_bucket_arn}/*",
        ]
      },
      {
        Sid    = "AllowKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          var.sse_encryption_arn
        ]
      }
    ]
  })
}

######################################
# SSH Key Creation (Optional)
######################################

resource "tls_private_key" "test_user_key" {
  count = var.create_test_user ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_secretsmanager_secret" "sftp_private_key" {
  count = var.create_test_user ? 1 : 0

  name        = "sftp-user-private-key-${local.test_user.username}-${random_pet.name.id}"
  description = "Private key for the SFTP test user"
  kms_key_id  = "alias/aws/secretsmanager"
}

resource "aws_secretsmanager_secret_version" "sftp_private_key_version" {
  count = var.create_test_user ? 1 : 0

  secret_id     = aws_secretsmanager_secret.sftp_private_key[0].id
  secret_string = tls_private_key.test_user_key[0].private_key_pem
}

######################################
# SFTP User Creation
######################################

# Create SFTP users
resource "aws_transfer_user" "transfer_users" {
  for_each = { for user in local.all_users : user.username => user }

  server_id = var.server_id
  user_name = each.value.username
  role      = each.value.role_arn == null || each.value.role_arn == "" ? aws_iam_role.sftp_user_role.arn : each.value.role_arn

  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/"
    target = "/${var.s3_bucket_name}${each.value.home_dir}"
  }
}

# Create SSH keys for users
resource "aws_transfer_ssh_key" "user_ssh_keys" {
  for_each = { for user in local.all_users : user.username => user }

  server_id = var.server_id
  user_name = each.value.username
  body      = each.value.public_key

  depends_on = [aws_transfer_user.transfer_users]
}
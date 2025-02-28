######################################
# IAM Role for SFTP users
######################################

# Create IAM role for SFTP users
# resource "aws_iam_role" "sftp_user_roles" {
#   for_each = { for user in var.users : user.username => user }

#   name = "transfer-user-${each.value.username}"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "transfer.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

resource "aws_iam_role" "sftp_user_role" {
  name = "basic-transfer-user"

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

# Update the IAM role policy for SFTP users
# resource "aws_iam_role_policy" "sftp_user_policies" {
#   for_each = { for user in var.users : user.username => user }

#   name = "sftp-user-policy-${each.value.username}"
#   role = aws_iam_role.sftp_user_roles[each.key].id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AllowListingOfUserFolder"
#         Effect = "Allow"
#         Action = [
#           "s3:ListBucket"
#         ]
#         Resource = [
#           var.s3_bucket_arn
#         ]
#       },
#       {
#         Sid    = "HomeDirObjectAccess"
#         Effect = "Allow"
#         Action = [
#           "s3:PutObject",
#           "s3:GetObject",
#           "s3:DeleteObject",
#         ]
#         Resource = [
#           "${var.s3_bucket_arn}${each.value.home_dir}/*",
#         ]
#       },
#       {
#         Sid    = "AllowKMSAccess"
#         Effect = "Allow"
#         Action = [
#           "kms:Decrypt",
#           "kms:GenerateDataKey"
#         ]
#         Resource = [
#           var.sse_encryption_arn
#         ]
#       }
#     ]
#   })
# }

resource "aws_iam_role_policy" "sftp_user_policies" {
  name = "sftp-user-policy"
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

resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 1
}

resource "tls_private_key" "sftp_keys" {
  for_each = var.create_ssh_keys ? { for user in var.users : user.username => user } : {}

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_secretsmanager_secret" "sftp_private_key" {
  for_each = var.create_ssh_keys ? { for user in var.users : user.username => user } : {}

  name        = "sftp-user-private-key-${each.key}-${random_pet.name.id}"
  description = "Private key for the SFTP user"
  kms_key_id  = "alias/aws/secretsmanager"
}

resource "aws_secretsmanager_secret_version" "sftp_private_key_version" {
  for_each = var.create_ssh_keys ? { for user in var.users : user.username => user } : {}

  secret_id     = aws_secretsmanager_secret.sftp_private_key[each.key].id
  secret_string = tls_private_key.sftp_keys[each.key].private_key_pem
}

######################################
# SFTP User Creation
######################################

# Create SFTP users
resource "aws_transfer_user" "transfer_users" {
  for_each = { for user in var.users : user.username => user }

  server_id = var.server_id
  user_name = each.value.username
  # role      = aws_iam_role.sftp_user_roles[each.key].arn
  # role      = each.value.role_arn != (null || "") ? each.value.role_arn : aws_iam_role.sftp_user_role.arn
  role      = each.value.role_arn == null || each.value.role_arn == "" ? aws_iam_role.sftp_user_role.arn : each.value.role_arn

  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/"
    target = "/${var.s3_bucket_name}${each.value.home_dir}"
  }
}

# Create SSH keys for users
resource "aws_transfer_ssh_key" "user_ssh_keys" {
  for_each = { for user in var.users : user.username => user }

  server_id = var.server_id
  user_name = each.value.username
  body      = var.create_ssh_keys ? tls_private_key.sftp_keys[each.key].public_key_openssh : (
      contains(keys(var.ssh_keys), each.key) ? var.ssh_keys[each.key] : null
  )

  depends_on = [aws_transfer_user.transfer_users]
}
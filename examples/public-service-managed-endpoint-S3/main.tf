#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

# S3 bucket creation
resource "aws_s3_bucket" "sftp_bucket" {
  bucket = var.bucket_name
}

# Create IAM role for SFTP users
resource "aws_iam_role" "sftp_user_role" {
  name = "sftp-user-role"

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
resource "aws_iam_role_policy" "sftp_user_policy" {
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
          aws_s3_bucket.sftp_bucket.arn
        ]
      },
      {
        Sid    = "HomeDirObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObjectVersion",
          "s3:GetObjectACL",
          "s3:PutObjectACL"
        ]
        Resource = [
          "${aws_s3_bucket.sftp_bucket.arn}/*",
          "${aws_s3_bucket.sftp_bucket.arn}"
        ]
      }
    ]
  })
}

module "transfer_server" {
  source = "../.."
  
  transfer_server_base = {
    domain        = "S3"
    protocols     = ["SFTP"]
    endpoint_type = "PUBLIC"
    environment   = "dev"
  }

  identity_provider = {
    type = "SERVICE_MANAGED"
  }
}

# Read users from CSV
locals {
  users = csvdecode(file(var.users_file))
}

module "sftp_keys" {
  source = "../../modules/sftp-keys"
  users  = local.users
}

# Create SFTP users
resource "aws_transfer_user" "sftp_users" {
  for_each = { for user in local.users : user.username => user }

  server_id = module.transfer_server.server_id
  user_name = each.value.username
  role      = aws_iam_role.sftp_user_role.arn

  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/"
    target = "/${var.bucket_name}${each.value.home_dir}"
  }
}

# Create SSH keys for users
resource "aws_transfer_ssh_key" "user_ssh_keys" {
  for_each = { for user in local.users : user.username => user }

  server_id = module.transfer_server.server_id
  user_name = each.value.username
    # body      = tls_private_key.sftp_keys[each.key].public_key_openssh
  body      = module.sftp_keys.public_keys[each.key]

  depends_on = [aws_transfer_user.sftp_users]
}
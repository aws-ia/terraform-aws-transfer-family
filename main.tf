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

# Transfer Server creation
resource "aws_transfer_server" "sftp" {
  identity_provider_type    = "SERVICE_MANAGED"
/*identity_provider_type    = "AWS_DIRECTORY_SERVICE"
  endpoint_type             = "VPC"  # Required for Directory Service
  directory_id              = "d-xxxx"  # Your Directory Service ID*/

/*identity_provider_type    = "AWS_LAMBDA"
  function_name             = "my-lambda-function"  # Your Lambda function name*/

/*identity_provider_type    = "API_GATEWAY"
  url                       = "https://api-gateway-url"  # Your API Gateway URL
  invocation_role           = aws_iam_role.api_gateway_role.arn*/

  domain                    = "S3" # Or "EFS" if you want to use EFS for storage
  protocols                 = ["SFTP"]
  endpoint_type             = "PUBLIC"  # Or "VPC" if you want to use VPC endpoint

#   hostname = "sftp.yourdomain.com"  # Your custom hostname
  tags = {
    Name = "sftp-server"
    Environment = var.environment
  }
}

# Read users from CSV
locals {
  users = csvdecode(file(var.users_file))
}

module "sftp_keys" {
  source = "./modules/sftp-keys"
  users  = local.users
}

# Create SFTP users
resource "aws_transfer_user" "sftp_users" {
  for_each = { for user in local.users : user.username => user }

  server_id = aws_transfer_server.sftp.id
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

  server_id = aws_transfer_server.sftp.id
  user_name = each.value.username
    # body      = tls_private_key.sftp_keys[each.key].public_key_openssh
  body      = module.sftp_keys.public_keys[each.key]

  depends_on = [aws_transfer_user.sftp_users]
}
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# Create the custom identity provider module with API Gateway
module "custom_idp" {
  source = "../../modules/transfer-custom-idp-solution"

  name_prefix = var.name_prefix

  # Enable API Gateway integration
  provision_api = true

  # VPC configuration
  create_vpc = false
  use_vpc    = false

  # Cognito configuration
  cognito_user_pool_name   = var.cognito_user_pool_name
  cognito_user_pool_client = var.cognito_user_pool_client

  tags = var.tags
}

# Generate secure random password
resource "random_password" "cognito_user" {
  length           = 16
  special          = true
  numeric          = true
  lower            = true
  upper            = true
  min_numeric      = 1
  min_special      = 1
  min_lower        = 1
  min_upper        = 1
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "cognito_user_password" {
  name_prefix             = "${var.name_prefix}-cognito-user-password-"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "cognito_user_password" {
  secret_id = aws_secretsmanager_secret.cognito_user_password.id
  secret_string = jsonencode({
    username = var.cognito_username
    password = random_password.cognito_user.result
  })
}

# Create Cognito user with secure password
resource "aws_cognito_user" "user" {
  user_pool_id = module.custom_idp.cognito_user_pool_id
  username     = var.cognito_username

  attributes = {
    email          = var.cognito_user_email
    email_verified = true
  }

  password = random_password.cognito_user.result

  lifecycle {
    ignore_changes = [password]
  }
}

# IAM role for Transfer Family users
resource "aws_iam_role" "transfer_role" {
  name = "${var.name_prefix}-transfer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "transfer_policy" {
  name = "${var.name_prefix}-transfer-policy"
  role = aws_iam_role.transfer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowListingOfUserFolder"
        Action = [
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.sftp_storage.arn
        ]
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "$${transfer:UserName}/*",
              "$${transfer:UserName}"
            ]
          }
        }
      },
      {
        Sid = "HomeDirObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObjectVersion",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:GetObjectACL",
          "s3:PutObjectACL"
        ]
        Resource = "$${aws_s3_bucket.sftp_storage.arn}/$${transfer:UserName}/*"
      }
    ]
  })
}

# Populate identity providers table
resource "aws_dynamodb_table_item" "cognito_provider" {
  table_name = module.custom_idp.identity_providers_table_name
  hash_key   = "provider"

  item = jsonencode({
    provider = {
      S = "user_pool"
    }
    public_key_support = {
      BOOL = false
    }
    config = {
      M = {
        cognito_client_id = {
          S = module.custom_idp.cognito_user_pool_client_id
        }
        cognito_user_pool_region = {
          S = var.aws_region
        }
        mfa = {
          BOOL = false
        }
      }
    }
    module = {
      S = "cognito"
    }
  })
}

# Populate users table
resource "aws_dynamodb_table_item" "user" {
  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  item = jsonencode({
    user = {
      S = var.cognito_username
    }
    identity_provider_key = {
      S = "user_pool"
    }
    config = {
      M = {
        HomeDirectoryDetails = {
          L = [
            {
              M = {
                Entry = {
                  S = "/"
                }
                Target = {
                  S = "/$${aws_s3_bucket.sftp_storage.bucket}/$${transfer:UserName}"
                }
              }
            }
          ]
        }
        HomeDirectoryType = {
          S = "LOGICAL"
        }
        Role = {
          S = aws_iam_role.transfer_role.arn
        }
      }
    }
    ipv4_allow_list = {
      SS = [
        "0.0.0.0/0"
      ]
    }
  })
}

# Create Transfer Family server with API Gateway URL as identity provider
resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "API_GATEWAY"
  url                   = module.custom_idp.api_gateway_url
  invocation_role       = module.custom_idp.transfer_invocation_role_arn
  
  protocols     = ["SFTP"]
  domain        = "S3"
  endpoint_type = "PUBLIC"

  tags = var.tags
}

# Create S3 bucket for file storage
resource "aws_s3_bucket" "sftp_storage" {
  bucket = "${var.bucket_prefix}-sftp-storage-${random_id.bucket_suffix.hex}"

  tags = var.tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "sftp_storage" {
  bucket = aws_s3_bucket.sftp_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sftp_storage" {
  bucket = aws_s3_bucket.sftp_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

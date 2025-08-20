#####################################################################################
# AWS Transfer Family with Custom IdP (Cognito) Example
# 
# This example demonstrates how to use the transfer-server module with the custom-idp
# module for Cognito authentication. After deployment, you can test SFTP authentication
# using Cognito users.
#####################################################################################

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Random naming for resources
resource "random_pet" "name" {
  prefix = "transfer-cognito"
  length = 2
}

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#####################################################################################
# Cognito User Pool for Authentication
#####################################################################################

resource "aws_cognito_user_pool" "transfer_users" {
  name = "${random_pet.name.id}-transfer-users"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # User attributes
  username_attributes = ["email"]
  
  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "transfer_client" {
  name         = "${random_pet.name.id}-transfer-client"
  user_pool_id = aws_cognito_user_pool.transfer_users.id

  # Authentication flows
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"
}

# Create a test user with permanent password
resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.transfer_users.id
  username     = var.test_username
  password     = var.test_user_password

  attributes = {
    email          = var.test_user_email
    email_verified = "true"
  }

  message_action = "SUPPRESS"  # Don't send welcome email
}

#####################################################################################
# S3 Bucket for SFTP Storage
#####################################################################################

resource "aws_s3_bucket" "transfer_storage" {
  bucket = "${random_pet.name.id}-transfer-storage"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "transfer_storage" {
  bucket = aws_s3_bucket.transfer_storage.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "transfer_storage" {
  bucket = aws_s3_bucket.transfer_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "transfer_storage" {
  bucket = aws_s3_bucket.transfer_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create test user directory (replace @ and . with - for S3 path)
resource "aws_s3_object" "test_user_directory" {
  bucket = aws_s3_bucket.transfer_storage.id
  key    = "${replace(replace(var.test_username, "@", "-"), ".", "-")}/"
  source = "/dev/null"
  tags   = var.tags
}

#####################################################################################
# IAM Role for Transfer Users
#####################################################################################

resource "aws_iam_role" "transfer_user_role" {
  name = "${random_pet.name.id}-transfer-user-role"

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

  tags = var.tags
}

resource "aws_iam_role_policy" "transfer_user_policy" {
  name = "${random_pet.name.id}-transfer-user-policy"
  role = aws_iam_role.transfer_user_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListingOfUserFolder"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.transfer_storage.arn]
        Condition = {
          StringLike = {
            "s3:prefix" = ["$${transfer:UserName}/*", "$${transfer:UserName}"]
          }
        }
      },
      {
        Sid    = "HomeDirObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Resource = ["${aws_s3_bucket.transfer_storage.arn}/$${transfer:UserName}/*"]
      }
    ]
  })
}

#####################################################################################
# Custom Identity Provider Module
#####################################################################################

module "custom_idp" {
  source = "../../modules/custom-idp"

  name_prefix = random_pet.name.id

  # Simple configuration - no VPC
  use_vpc = false

  # Basic Lambda configuration
  lambda_timeout     = 30
  lambda_memory_size = 512

  # Logging
  log_level               = "INFO"
  log_retention_in_days   = 7

  # Disable optional features for simplicity
  enable_api_gateway                    = false
  enable_secrets_manager_permissions    = false
  enable_xray_tracing                  = false
  enable_point_in_time_recovery        = true

  tags = var.tags
}

#####################################################################################
# Transfer Server with Custom IdP
#####################################################################################

module "transfer_server" {
  source = "../../modules/transfer-server"

  server_name = "${random_pet.name.id}-server"

  # Custom Identity Provider Integration
  identity_provider   = "AWS_LAMBDA"
  lambda_function_arn = module.custom_idp.lambda_function_arn

  # Basic configuration
  protocols     = ["SFTP"]
  endpoint_type = "PUBLIC"
  domain        = "S3"

  # Logging
  enable_logging     = true
  log_retention_days = 7

  tags = var.tags
}

#####################################################################################
# DynamoDB Configuration (Post-Deployment)
#####################################################################################

# Configure Cognito identity provider in DynamoDB
resource "aws_dynamodb_table_item" "cognito_provider" {
  table_name = module.custom_idp.identity_providers_table_name
  hash_key   = "provider"

  item = jsonencode({
    provider = {
      S = "cognito"
    }
    module = {
      S = "cognito"
    }
    config = {
      M = {
        cognito_client_id = {
          S = aws_cognito_user_pool_client.transfer_client.id
        }
        cognito_user_pool_region = {
          S = data.aws_region.current.name
        }
      }
    }
  })

  depends_on = [module.custom_idp]
}

# Configure test user in DynamoDB
resource "aws_dynamodb_table_item" "test_user" {
  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  item = jsonencode({
    user = {
      S = var.test_username
    }
    identity_provider_key = {
      S = "cognito"
    }
    config = {
      M = {
        Role = {
          S = aws_iam_role.transfer_user_role.arn
        }
        HomeDirectory = {
          S = "/${aws_s3_bucket.transfer_storage.id}/${replace(replace(var.test_username, "@", "-"), ".", "-")}"
        }
      }
    }
  })

  depends_on = [module.custom_idp, aws_cognito_user.test_user]
}
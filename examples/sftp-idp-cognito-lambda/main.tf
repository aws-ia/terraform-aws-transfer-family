terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# SFTP Server using Lambda identity provider
module "transfer_server" {
  source = "../../"

  server_name         = "cognito-sftp-server"
  identity_provider   = "AWS_LAMBDA"
  lambda_function_arn = module.custom_idp.lambda_function_arn

  enable_logging = true
  
  tags = {
    Environment = "Demo"
    Project     = "SFTP Cognito Lambda"
  }
}

# DynamoDB Tables
resource "aws_dynamodb_table" "users" {
  name           = "cognito-transfer-idp-users"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "Username"

  attribute {
    name = "Username"
    type = "S"
  }
}

resource "aws_dynamodb_table" "identity_providers" {
  name           = "cognito-transfer-idp-identity-providers"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ServerId"

  attribute {
    name = "ServerId"
    type = "S"
  }
}

# Custom Identity Provider with Cognito
module "custom_idp" {
  source = "../../modules/custom-idps-nizar"

  stack_name                       = "cognito-transfer-idp"
  aws_region                      = var.aws_region
  lambda_zip_path                 = "${path.module}/lambda.zip"
  users_table_name                = "cognito-transfer-idp-users"
  identity_providers_table_name   = "cognito-transfer-idp-identity-providers"
}

# Seed DynamoDB users table with mock users
resource "aws_dynamodb_table_item" "mock_user_1" {
  table_name = aws_dynamodb_table.users.name
  hash_key   = aws_dynamodb_table.users.hash_key

  item = jsonencode({
    Username = {
      S = "testuser1@@cognito"
    }
    Role = {
      S = aws_iam_role.sftp_user_role.arn
    }
    HomeDirectory = {
      S = "/demo-sftp-bucket/testuser1/"
    }
    Policy = {
      S = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = "arn:aws:s3:::demo-sftp-bucket/testuser1/*"
          }
        ]
      })
    }
  })
}

resource "aws_dynamodb_table_item" "mock_user_2" {
  table_name = aws_dynamodb_table.users.name
  hash_key   = aws_dynamodb_table.users.hash_key

  item = jsonencode({
    Username = {
      S = "testuser2@@cognito"
    }
    Role = {
      S = aws_iam_role.sftp_user_role.arn
    }
    HomeDirectory = {
      S = "/demo-sftp-bucket/testuser2/"
    }
    Policy = {
      S = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = "arn:aws:s3:::demo-sftp-bucket/testuser2/*"
          }
        ]
      })
    }
  })
}

# Seed identity providers table with Cognito config
resource "aws_dynamodb_table_item" "cognito_idp" {
  table_name = aws_dynamodb_table.identity_providers.name
  hash_key   = aws_dynamodb_table.identity_providers.hash_key

  item = jsonencode({
    ServerId = {
      S = module.transfer_server.server_id
    }
    provider = {
      S = "cognito"
    }
    config = {
      M = {
        cognito_client_id = {
          S = aws_cognito_user_pool_client.sftp_client.id
        }
        cognito_user_pool_region = {
          S = var.aws_region
        }
        mfa = {
          BOOL = false
        }
      }
    }
  })
}

# IAM role for SFTP users
resource "aws_iam_role" "sftp_user_role" {
  name = "cognito-sftp-user-role"

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

resource "aws_iam_role_policy" "sftp_user_policy" {
  name = "cognito-sftp-user-policy"
  role = aws_iam_role.sftp_user_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::demo-sftp-bucket"
      }
    ]
  })
}

# Cognito User Pool for authentication
resource "aws_cognito_user_pool" "sftp_users" {
  name = "sftp-users"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }
}

resource "aws_cognito_user_pool_client" "sftp_client" {
  name         = "sftp-client"
  user_pool_id = aws_cognito_user_pool.sftp_users.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# Create mock users in Cognito
resource "aws_cognito_user" "testuser1" {
  user_pool_id = aws_cognito_user_pool.sftp_users.id
  username     = "testuser1"
  password     = "TempPass123!"
  
  attributes = {
    email = "testuser1@example.com"
  }
}

resource "aws_cognito_user" "testuser2" {
  user_pool_id = aws_cognito_user_pool.sftp_users.id
  username     = "testuser2"
  password     = "TempPass123!"
  
  attributes = {
    email = "testuser2@example.com"
  }
}

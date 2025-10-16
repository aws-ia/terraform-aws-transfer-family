terraform {
  required_version = ">= 1.5"
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

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 bucket for SFTP users
resource "aws_s3_bucket" "sftp_bucket" {
  bucket = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "sftp_bucket" {
  bucket = aws_s3_bucket.sftp_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Cognito User Pool
resource "aws_cognito_user_pool" "sftp_users" {
  name = var.cognito_user_pool_name

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  mfa_configuration = "OPTIONAL"
  software_token_mfa_configuration {
    enabled = true
  }
}

resource "aws_cognito_user_pool_client" "sftp_client" {
  name         = "${var.cognito_user_pool_name}-client"
  user_pool_id = aws_cognito_user_pool.sftp_users.id

  explicit_auth_flows = [
    "ADMIN_NO_SRP_AUTH",
    "USER_PASSWORD_AUTH"
  ]
}

# DynamoDB table for Transfer Family configuration
resource "aws_dynamodb_table" "transfer_config" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "provider"

  attribute {
    name = "provider"
    type = "S"
  }

  tags = var.tags
}

# Seed DynamoDB with configuration
resource "aws_dynamodb_table_item" "cognito_config" {
  table_name = aws_dynamodb_table.transfer_config.name
  hash_key   = aws_dynamodb_table.transfer_config.hash_key

  item = jsonencode({
    provider = {
      S = "cognito"
    }
    config = {
      M = {
        mfa_token_length = {
          N = "6"
        }
        cognito_client_id = {
          S = aws_cognito_user_pool_client.sftp_client.id
        }
        cognito_user_pool_region = {
          S = data.aws_region.current.name
        }
        mfa = {
          BOOL = true
        }
      }
    }
    module = {
      S = "cognito"
    }
  })
}

# Create 5 test users in Cognito
resource "aws_cognito_user" "sftp_users" {
  count      = 5
  user_pool_id = aws_cognito_user_pool.sftp_users.id
  username     = "sftpuser${count.index + 1}"
  
  attributes = {
    email = "sftpuser${count.index + 1}@example.com"
  }

  password = "Password123!"
  message_action = "SUPPRESS"
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.transfer_config.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminInitiateAuth",
          "cognito-idp:AdminGetUser",
          "cognito-idp:ListUserPools",
          "cognito-idp:ListUserPoolClients"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.sftp_bucket.arn}/*"
      }
    ]
  })
}

# Lambda function for custom identity provider
resource "aws_lambda_function" "transfer_identity_provider" {
  filename         = "transfer_identity_provider.zip"
  function_name    = "${var.project_name}-identity-provider"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 30

  depends_on = [data.archive_file.lambda_zip]

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.transfer_config.name
      S3_BUCKET      = aws_s3_bucket.sftp_bucket.bucket
      PROJECT_NAME   = var.project_name
      SFTP_ROLE_ARN  = aws_iam_role.sftp_user_role.arn
    }
  }
}

# Lambda permission for Transfer Family
resource "aws_lambda_permission" "transfer_invoke" {
  statement_id  = "AllowTransferFamilyInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transfer_identity_provider.function_name
  principal     = "transfer.amazonaws.com"
}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "transfer_identity_provider.zip"
  source {
    content  = file("${path.module}/lambda_function.py")
    filename = "index.py"
  }
}

# Transfer Family Server
module "transfer_server" {
  source = "../../"

  server_name           = var.server_name
  identity_provider     = "AWS_LAMBDA"
  lambda_function_arn   = aws_lambda_function.transfer_identity_provider.arn
  protocols            = ["SFTP"]
  endpoint_type        = "PUBLIC"
  enable_logging       = true
  log_retention_days   = 7

  tags = var.tags
}

# IAM role for SFTP users
resource "aws_iam_role" "sftp_user_role" {
  name = "${var.project_name}-sftp-user-role"

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
  name = "${var.project_name}-sftp-user-policy"
  role = aws_iam_role.sftp_user_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.sftp_bucket.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.sftp_bucket.arn}/*"
      }
    ]
  })
}

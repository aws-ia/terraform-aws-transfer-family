terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"
  
  source {
    content = file("${path.module}/../../modules/custom-idps-nizar/app.py")
    filename = "app.py"
  }
  
  source {
    content = file("${path.module}/../../modules/custom-idps-nizar/cognito.py")
    filename = "cognito.py"
  }
  
  source {
    content = "from app import handler"
    filename = "index.py"
  }
}

# Cognito User Pool
resource "aws_cognito_user_pool" "transfer_users" {
  name = "${var.stack_name}-transfer-users"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "transfer_client" {
  name         = "${var.stack_name}-transfer-client"
  user_pool_id = aws_cognito_user_pool.transfer_users.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  generate_secret = false
}

# Test user in Cognito
resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.transfer_users.id
  username     = var.test_username

  attributes = {
    email = var.test_email
  }

  temporary_password = var.test_password
  message_action     = "SUPPRESS"
}

resource "aws_cognito_user" "test_user_permanent_password" {
  user_pool_id = aws_cognito_user_pool.transfer_users.id
  username     = "${var.test_username}-permanent"

  password = var.test_password

  attributes = {
    email = var.test_email
  }
}

# Custom IDP module
module "custom_idp" {
  source = "../../modules/custom-idps-nizar"

  stack_name      = var.stack_name
  lambda_zip_path = data.archive_file.lambda_zip.output_path
  use_vpc         = false
  provision_api   = true
  enable_tracing  = true

  tags = var.tags
}

# Seed DynamoDB with identity provider config
resource "aws_dynamodb_table_item" "cognito_idp_config" {
  table_name = module.custom_idp.identity_providers_table_name
  hash_key   = module.custom_idp.identity_providers_table_hash_key

  item = jsonencode({
    ServerId = {
      S = aws_transfer_server.sftp.id
    }
    config = {
      M = {
        cognito_client_id = {
          S = aws_cognito_user_pool_client.transfer_client.id
        }
        cognito_user_pool_region = {
          S = var.aws_region
        }
        mfa = {
          BOOL = false
        }
      }
    }
    provider = {
      S = "cognito"
    }
  })
}

# Seed DynamoDB with test user
resource "aws_dynamodb_table_item" "test_user" {
  table_name = module.custom_idp.users_table_name
  hash_key   = module.custom_idp.users_table_hash_key

  item = jsonencode({
    Username = {
      S = var.test_username
    }
    HomeDirectory = {
      S = "/${aws_s3_bucket.sftp_bucket.bucket}/${var.test_username}"
    }
    Role = {
      S = aws_iam_role.transfer_user_role.arn
    }
    Policy = {
      S = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:ListBucket"
            ]
            Resource = aws_s3_bucket.sftp_bucket.arn
            Condition = {
              StringLike = {
                "s3:prefix" = ["${var.test_username}/*"]
              }
            }
          },
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = "${aws_s3_bucket.sftp_bucket.arn}/${var.test_username}/*"
          }
        ]
      })
    }
  })
}

# S3 bucket for SFTP
resource "aws_s3_bucket" "sftp_bucket" {
  bucket = "${var.stack_name}-sftp-${random_id.bucket_suffix.hex}"

  tags = var.tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# IAM role for transfer users
resource "aws_iam_role" "transfer_user_role" {
  name = "${var.stack_name}-transfer-user-role"

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

# Transfer server
resource "aws_transfer_server" "sftp" {
  identity_provider_type = "API_GATEWAY"
  url                   = module.custom_idp.api_gateway_url
  invocation_role       = module.custom_idp.api_gateway_role_arn
  protocols             = ["SFTP"]
  endpoint_type         = "PUBLIC"

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }

  tags = merge(var.tags, {
    Name = "${var.stack_name}-sftp-server"
  })

  depends_on = [module.custom_idp]
}

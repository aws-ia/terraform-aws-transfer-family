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

# Create the custom identity provider module with API Gateway
module "custom_idp" {
  source = "../../modules/custom-idps"

  # Enable API Gateway integration
  use_api_gateway = true
  
  # DynamoDB table names
  users_table_name             = "sftp-users"
  identity_providers_table_name = "sftp-identity-providers"
  
  # Cognito configuration
  cognito_user_pool_name   = var.cognito_user_pool_name
  cognito_user_pool_client = var.cognito_user_pool_client

  tags = var.tags
}

# CloudWatch log groups for debugging
resource "aws_cloudwatch_log_group" "transfer_logs" {
  name              = "/aws/transfer/${aws_transfer_server.sftp_server.id}"
  retention_in_days = 7
  
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${module.custom_idp.lambda_function_name}"
  retention_in_days = 7
  
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/transfer-api-gateway"
  retention_in_days = 7
  
  tags = var.tags
}

# IAM role for Transfer Family users
resource "aws_iam_role" "transfer_role" {
  name = "sftp-cognito-example-AWSTransferRole"

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
}

resource "aws_iam_role_policy" "transfer_policy" {
  name = "sftp-cognito-example-transfer-policy"
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
        Resource = "${aws_s3_bucket.sftp_storage.arn}/$${transfer:UserName}/*"
      }
    ]
  })
}

# Create Transfer Family server with API Gateway URL as identity provider
resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "API_GATEWAY"
  url                   = module.custom_idp.api_gateway_url
  invocation_role       = module.custom_idp.transfer_invocation_role_arn
  logging_role          = aws_iam_role.transfer_logging_role.arn
  
  protocols     = ["SFTP"]
  domain        = "S3"
  endpoint_type = "PUBLIC"

  tags = var.tags
}

# IAM role for Transfer server logging
resource "aws_iam_role" "transfer_logging_role" {
  name = "sftp-cognito-gateway-logging-role"

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
}

resource "aws_iam_role_policy_attachment" "transfer_logging_policy" {
  role       = aws_iam_role.transfer_logging_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSTransferLoggingAccess"
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
# Create test user in Cognito
resource "null_resource" "create_cognito_user" {
  provisioner "local-exec" {
    command = <<-EOT
      aws cognito-idp admin-create-user \
        --user-pool-id ${module.custom_idp.cognito_user_pool_id} \
        --username 'user1' \
        --temporary-password 'TempPass123!' \
        --message-action SUPPRESS --region ${var.aws_region} || true
      
      aws cognito-idp admin-set-user-password \
        --user-pool-id ${module.custom_idp.cognito_user_pool_id} \
        --username 'user1' \
        --password 'MySecurePass123!' \
        --permanent --region ${var.aws_region}
    EOT
  }

  depends_on = [module.custom_idp]
}

# Populate identity providers table
resource "aws_dynamodb_table_item" "cognito_provider" {
  table_name = module.custom_idp.identity_providers_table_name
  hash_key   = "provider"

  item = jsonencode({
    provider = {
      S = aws_transfer_server.sftp_server.id
    }
    config = {
      M = {
        cognito_client_id = {
          S = module.custom_idp.cognito_user_pool_client_id
        }
        cognito_user_pool_region = {
          S = var.aws_region
        }
        cognito_user_pool_id = {
          S = module.custom_idp.cognito_user_pool_id
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

  depends_on = [module.custom_idp, aws_transfer_server.sftp_server]
}

# Populate users table
resource "aws_dynamodb_table_item" "test_user" {
  table_name = module.custom_idp.users_table_name
  hash_key   = "user"

  item = jsonencode({
    user = {
      S = "user1"
    }
    identity_provider_key = {
      S = aws_transfer_server.sftp_server.id
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
                  S = "/${aws_s3_bucket.sftp_storage.bucket}/user1"
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
  })

  depends_on = [module.custom_idp, aws_s3_bucket.sftp_storage, aws_iam_role.transfer_role]
}

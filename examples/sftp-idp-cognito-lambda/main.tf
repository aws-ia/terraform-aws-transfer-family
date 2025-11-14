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

data "aws_caller_identity" "current" {}

# S3 bucket for user files
resource "aws_s3_bucket" "transfer_files" {
  bucket = "${var.stack_name}-awstransfer-filestest-${data.aws_caller_identity.current.account_id}"
}

# IAM role for Transfer Family users
resource "aws_iam_role" "transfer_role" {
  name = "${var.stack_name}-AWSTransferRole"

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
  name = "${var.stack_name}-transfer-policy"
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
          aws_s3_bucket.transfer_files.arn
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
        Resource = "${aws_s3_bucket.transfer_files.arn}/$${transfer:UserName}/*"
      }
    ]
  })
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

  generate_secret = false
  explicit_auth_flows = [
    "ADMIN_NO_SRP_AUTH",
    "USER_PASSWORD_AUTH"
  ]
}

# Create Cognito user that matches DynamoDB user record
resource "null_resource" "create_cognito_user" {
  provisioner "local-exec" {
    command = <<-EOT
      aws cognito-idp admin-create-user \
        --user-pool-id ${aws_cognito_user_pool.transfer_users.id} \
        --username 'user1' \
        --temporary-password 'TempPass123!' \
        --message-action SUPPRESS || true
      
      aws cognito-idp admin-set-user-password \
        --user-pool-id ${aws_cognito_user_pool.transfer_users.id} \
        --username 'user1' \
        --password 'MySecurePass123!' \
        --permanent
    EOT
  }

  depends_on = [aws_cognito_user_pool.transfer_users]
}

# Custom IDP module
module "custom_idp" {
  source = "../../modules/custom-idps"

  stack_name                      = var.stack_name
  users_table_name               = "${var.stack_name}-users"
  identity_providers_table_name  = "${var.stack_name}-identity-providers"
  
  create_vpc = false
  use_vpc    = false
  provision_api = false
  
  tags = var.tags
}

# Populate identity providers table
resource "aws_dynamodb_table_item" "cognito_provider" {
  table_name = module.custom_idp.identity_providers_table_name
  hash_key   = "provider"

  item = jsonencode({
    provider = {
      S = "domain2019.local"
    }
    public_key_support = {
      BOOL = false
    }
    config = {
      M = {
        cognito_client_id = {
          S = aws_cognito_user_pool_client.transfer_client.id
        }
        cognito_user_pool_region = {
          S = "us-east-1"
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

# Populate users table with mock user
resource "aws_dynamodb_table_item" "mock_user" {
  table_name = module.custom_idp.users_table_name
  hash_key   = "user"

  item = jsonencode({
    user = {
      S = "user1"
    }
    identity_provider_key = {
      S = "domain2019.local"
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
                  S = "/${aws_s3_bucket.transfer_files.bucket}/$${transfer:UserName}"
                }
              }
            }
          ]
        }
        HomeDirectoryType = {
          S = "LOGICAL"
        }
        Policy = {
          S = jsonencode({
            Version = "2012-10-17"
            Statement = [
              {
                Sid = "AllowListingOfUserFolder"
                Action = [
                  "s3:ListBucket"
                ]
                Effect = "Allow"
                Resource = [
                  aws_s3_bucket.transfer_files.arn
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
                Resource = "${aws_s3_bucket.transfer_files.arn}/$${transfer:UserName}/*"
              }
            ]
          })
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

# Transfer Server with Lambda identity provider
resource "aws_transfer_server" "sftp" {
  identity_provider_type = "AWS_LAMBDA"
  function              = module.custom_idp.lambda_function_arn
  protocols             = ["SFTP"]
  endpoint_type         = "PUBLIC"
  logging_role          = aws_iam_role.transfer_logging_role.arn

  tags = var.tags
}

# CloudWatch log group for Transfer server
resource "aws_cloudwatch_log_group" "transfer_logs" {
  name              = "/aws/transfer/${aws_transfer_server.sftp.id}"
  retention_in_days = 7
}

# CloudWatch log group for Lambda function
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${module.custom_idp.lambda_function_name}"
  retention_in_days = 7
}

# IAM role for Transfer server logging
resource "aws_iam_role" "transfer_logging_role" {
  name = "${var.stack_name}-transfer-logging-role"

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

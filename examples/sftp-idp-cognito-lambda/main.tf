provider "aws" {
  region = var.aws_region
}

######################################
# Defaults and Locals
######################################

data "aws_caller_identity" "current" {}

resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 1
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  server_name = "transfer-server-${random_pet.name.id}"
}

###################################################################
# S3 Bucket for Transfer Family
###################################################################
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "${random_pet.name.id}-${random_id.suffix.hex}-transfer-files"

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    status     = true
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = var.tags
}

###################################################################
# IAM Role for Transfer Family Session
###################################################################
resource "aws_iam_role" "transfer_session" {
  name = "${var.name_prefix}-transfer-session-role"

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

resource "aws_iam_role_policy" "transfer_session_s3" {
  name = "transfer-session-s3-access"
  role = aws_iam_role.transfer_session.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListingOfUserFolder"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = module.s3_bucket.s3_bucket_arn
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
        Resource = "${module.s3_bucket.s3_bucket_arn}/*"
      }
    ]
  })
}

###################################################################
# Custom IDP module
###################################################################
module "custom_idp" {
  source = "../../modules/transfer-custom-idp-solution"

  name_prefix                     = var.name_prefix
  users_table_name                = ""
  identity_providers_table_name   = ""
  create_vpc                      = false
  use_vpc                         = false
  provision_api                   = false
  
  tags = var.tags
}

###################################################################
# Cognito User Pool
###################################################################
resource "aws_cognito_user_pool" "transfer_users" {
  name = "${var.name_prefix}-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "transfer_client" {
  name         = "${var.name_prefix}-client"
  user_pool_id = aws_cognito_user_pool.transfer_users.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# Generate secure random password for Cognito user
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

# Create Cognito user with generated password
resource "aws_cognito_user" "transfer_user" {
  user_pool_id = aws_cognito_user_pool.transfer_users.id
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

# Store Cognito user password securely in Secrets Manager
resource "aws_secretsmanager_secret" "cognito_user_password" {
  #checkov:skip=CKV_AWS_149:Using AWS managed encryption is acceptable for this example
  name_prefix             = "${var.name_prefix}-cognito-password-"
  recovery_window_in_days = 0

  tags = var.tags
}

# Store password value in Secrets Manager
resource "aws_secretsmanager_secret_version" "cognito_user_password" {
  secret_id = aws_secretsmanager_secret.cognito_user_password.id
  secret_string = jsonencode({
    username = var.cognito_username
    password = random_password.cognito_user.result
  })
}

###################################################################
# DynamoDB Configuration
###################################################################

# Populate identity providers table with Cognito user pool details
resource "aws_dynamodb_table_item" "cognito_provider" {
  table_name = module.custom_idp.identity_providers_table_name
  hash_key   = "provider"

  depends_on = [module.custom_idp]

  item = jsonencode({
    provider = {
      S = "cognito_pool"
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

# Create user record for Cognito user
resource "aws_dynamodb_table_item" "cognito_user_record" {
  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.custom_idp, aws_cognito_user.transfer_user]

  item = jsonencode({
    user = {
      S = var.cognito_username
    }
    identity_provider_key = {
      S = "cognito_pool"
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
                  S = "/${module.s3_bucket.s3_bucket_id}/$${transfer:UserName}"
                }
              }
            }
          ]
        }
        HomeDirectoryType = {
          S = "LOGICAL"
        }
        Role = {
          S = aws_iam_role.transfer_session.arn
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

###################################################################
# Transfer Server using transfer_server module
###################################################################
module "transfer_server" {
  source = "../../modules/transfer-server"
  
  domain                   = "S3"
  protocols                = ["SFTP"]
  endpoint_type            = "PUBLIC"
  server_name              = local.server_name
  identity_provider        = "AWS_LAMBDA"
  lambda_function_arn      = module.custom_idp.lambda_function_arn
  security_policy_name     = "TransferSecurityPolicy-2024-01"
  enable_logging           = true
  logging_role             = var.logging_role
  workflow_details         = var.workflow_details
  
  tags = var.tags
}

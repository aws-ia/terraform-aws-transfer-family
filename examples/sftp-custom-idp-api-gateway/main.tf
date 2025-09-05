#####################################################################################
# AWS Transfer Family with Custom IdP (API Gateway) Example
# 
# This example demonstrates how to use the transfer-server module with the custom-idp
# module using API Gateway REST integration instead of direct Lambda integration.
# This approach provides additional flexibility for authentication workflows and
# can be useful for integration with external systems.
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
  prefix = "transfer-api-gateway"
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

# Create test users with permanent passwords
resource "aws_cognito_user" "test_user_1" {
  user_pool_id = aws_cognito_user_pool.transfer_users.id
  username     = var.test_user_1.username
  password     = var.test_user_1.password

  attributes = {
    email          = var.test_user_1.email
    email_verified = "true"
  }

  message_action = "SUPPRESS"  # Don't send welcome email
}

resource "aws_cognito_user" "test_user_2" {
  user_pool_id = aws_cognito_user_pool.transfer_users.id
  username     = var.test_user_2.username
  password     = var.test_user_2.password

  attributes = {
    email          = var.test_user_2.email
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

# Create test user directories
resource "aws_s3_object" "test_user_1_directory" {
  bucket = aws_s3_bucket.transfer_storage.id
  key    = "${replace(replace(var.test_user_1.username, "@", "-"), ".", "-")}/"
  source = "/dev/null"
  tags   = var.tags
}

resource "aws_s3_object" "test_user_2_directory" {
  bucket = aws_s3_bucket.transfer_storage.id
  key    = "${replace(replace(var.test_user_2.username, "@", "-"), ".", "-")}/"
  source = "/dev/null"
  tags   = var.tags
}

#####################################################################################
# IAM Roles for Transfer Users
#####################################################################################

# Admin user role (full bucket access)
resource "aws_iam_role" "transfer_admin_role" {
  name = "${random_pet.name.id}-transfer-admin-role"

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

resource "aws_iam_role_policy" "transfer_admin_policy" {
  name = "${random_pet.name.id}-transfer-admin-policy"
  role = aws_iam_role.transfer_admin_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowFullBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [aws_s3_bucket.transfer_storage.arn]
      },
      {
        Sid    = "AllowFullObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Resource = ["${aws_s3_bucket.transfer_storage.arn}/*"]
      }
    ]
  })
}

# Regular user role (restricted to user directory)
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
# Custom Identity Provider Module with API Gateway
#####################################################################################

module "custom_idp" {
  source = "../../modules/custom-idp"

  name_prefix = random_pet.name.id

  # Enable API Gateway integration
  enable_api_gateway = true

  # Simple configuration - no VPC
  use_vpc = false

  # Lambda configuration
  lambda_timeout     = 30
  lambda_memory_size = 512

  # Enable additional features for API Gateway example
  enable_secrets_manager_permissions = true
  enable_cognito_permissions         = true
  enable_xray_tracing               = true
  
  # Specify Cognito User Pool ARN for least privilege access
  cognito_user_pool_arns = [
    "arn:aws:cognito-idp:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:userpool/${aws_cognito_user_pool.transfer_users.id}"
  ]

  # Logging
  log_level               = "DEBUG"  # More verbose for API Gateway debugging
  log_retention_in_days   = 14

  # DynamoDB configuration
  enable_point_in_time_recovery = true

  tags = var.tags
}

#####################################################################################
# Transfer Server with API Gateway Integration
#####################################################################################

module "transfer_server" {
  source = "../../modules/transfer-server"

  server_name = "${random_pet.name.id}-server"

  # API Gateway Integration (instead of direct Lambda)
  identity_provider = "API_GATEWAY"
  api_gateway_url   = module.custom_idp.api_gateway_url

  # Basic configuration
  protocols     = ["SFTP"]
  endpoint_type = "PUBLIC"
  domain        = "S3"

  # Logging
  enable_logging     = true
  log_retention_days = 14

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
    public_key_support = {
      BOOL = false
    }
    disabled = {
      BOOL = false
    }
  })

  depends_on = [module.custom_idp]
}

# Configure LDAP identity provider (example of multiple IDPs)
resource "aws_dynamodb_table_item" "ldap_provider" {
  table_name = module.custom_idp.identity_providers_table_name
  hash_key   = "provider"

  item = jsonencode({
    provider = {
      S = "ldap"
    }
    module = {
      S = "ldap"
    }
    config = {
      M = {
        ldap_server = {
          S = var.ldap_config.server
        }
        ldap_port = {
          N = tostring(var.ldap_config.port)
        }
        ldap_base_dn = {
          S = var.ldap_config.base_dn
        }
        ldap_bind_dn = {
          S = var.ldap_config.bind_dn
        }
        ldap_bind_password_secret = {
          S = var.ldap_config.bind_password_secret
        }
      }
    }
    public_key_support = {
      BOOL = false
    }
    disabled = {
      BOOL = var.ldap_config.disabled
    }
  })

  depends_on = [module.custom_idp]
}

# Configure admin test user (uses Cognito)
resource "aws_dynamodb_table_item" "test_user_1" {
  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  item = jsonencode({
    user = {
      S = var.test_user_1.username
    }
    identity_provider_key = {
      S = "cognito"
    }
    config = {
      M = {
        Role = {
          S = aws_iam_role.transfer_admin_role.arn
        }
        HomeDirectory = {
          S = "/${aws_s3_bucket.transfer_storage.id}"
        }
      }
    }
  })

  depends_on = [module.custom_idp, aws_cognito_user.test_user_1]
}

# Configure regular test user (uses Cognito, restricted access)
resource "aws_dynamodb_table_item" "test_user_2" {
  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  item = jsonencode({
    user = {
      S = var.test_user_2.username
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
          S = "/${aws_s3_bucket.transfer_storage.id}/${replace(replace(var.test_user_2.username, "@", "-"), ".", "-")}"
        }
      }
    }
  })

  depends_on = [module.custom_idp, aws_cognito_user.test_user_2]
}

# Configure default user (uses LDAP for unknown users)
resource "aws_dynamodb_table_item" "default_user" {
  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  item = jsonencode({
    user = {
      S = "$default$"
    }
    identity_provider_key = {
      S = "ldap"
    }
    config = {
      M = {
        Role = {
          S = aws_iam_role.transfer_user_role.arn
        }
        HomeDirectory = {
          S = "/${aws_s3_bucket.transfer_storage.id}/$${USERNAME}"
        }
      }
    }
  })

  depends_on = [module.custom_idp]
}

#####################################################################################
# CloudWatch Dashboard for Monitoring
#####################################################################################

resource "aws_cloudwatch_dashboard" "transfer_monitoring" {
  dashboard_name = "${random_pet.name.id}-transfer-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Transfer", "FilesIn", "ServerId", module.transfer_server.server_id],
            [".", "FilesOut", ".", "."],
            [".", "InboundBytes", ".", "."],
            [".", "OutboundBytes", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Transfer Family Metrics"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '${module.custom_idp.lambda_log_group_name}'\n| fields @timestamp, @message\n| sort @timestamp desc\n| limit 100"
          region  = data.aws_region.current.name
          title   = "Custom IdP Lambda Logs"
        }
      }
    ]
  })
}
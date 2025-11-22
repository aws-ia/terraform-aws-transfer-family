provider "aws" {
  region = "us-east-1"
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get S3 bucket ARN
data "aws_s3_bucket" "transfer_files" {
  bucket = var.s3_bucket_name
}

# IAM Role for Transfer Family Session
resource "aws_iam_role" "transfer_session" {
  name = "transfer-session-role"

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

  tags = {
    Environment = "production"
    Project     = "file-transfer"
    ManagedBy   = "terraform"
  }
}

# IAM Policy for S3 Access
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
        Resource = data.aws_s3_bucket.transfer_files.arn
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
        Resource = "${data.aws_s3_bucket.transfer_files.arn}/*"
      }
    ]
  })
}

module "transfer_custom_idp" {
  source = "../../"

  name_prefix = "transferidp"
  force_build = true

  # VPC Configuration - VPC attachment is needed for private identity providers such as Active Directory
  use_vpc = false

  # Optional API Gateway to invoke the Lambda - Useful when using Web Application Firewall to filter authentication requests
  provision_api = false

  # Enable Secrets Manager access - Depending on the identity provider, the solution may need to retrieve credentials in Secrets Manager
  secrets_manager_permissions = true

  # Tags
  tags = {
    Environment = "production"
    Project     = "file-transfer"
    ManagedBy   = "terraform"
  }
}

# Populate identity providers table with the details of the Cognito user pool. Set the provider module to "cognito"
resource "aws_dynamodb_table_item" "cognito_provider" {
  table_name = module.transfer_custom_idp.identity_providers_table_name
  hash_key   = "provider"

  depends_on = [module.transfer_custom_idp]

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
          S = var.cognito_user_pool_client_id
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

# Create a user record for the cognito user associated with AnyCompany Auto Repair and assign the directory anycompany-auto-repairs to them.
resource "aws_dynamodb_table_item" "anycompany_repair_record" {
  table_name = module.transfer_custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.transfer_custom_idp]

  item = jsonencode({
    user = {
      S = "anycompany.repairs"
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
                  S = "/${var.s3_bucket_name}/$${transfer:UserName}"
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



# Outputs
output "lambda_function_name" {
  value = module.transfer_custom_idp.lambda_function_name
}

output "lambda_function_arn" {
  value = module.transfer_custom_idp.lambda_function_arn
}

output "users_table_name" {
  value = module.transfer_custom_idp.users_table_name
}

output "identity_providers_table_name" {
  value = module.transfer_custom_idp.identity_providers_table_name
}

output "transfer_session_role_arn" {
  description = "ARN of the Transfer Family session role"
  value       = aws_iam_role.transfer_session.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket used for Transfer Family"
  value       = var.s3_bucket_name
}

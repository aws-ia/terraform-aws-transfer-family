################################################################################
# Stage 1: Transfer Server with Custom IDP
# Components: Transfer Family Server, Custom IDP Solution, S3 Bucket
################################################################################

################################################################################
# Data Sources
################################################################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# Random Naming
################################################################################

# Generate random name for consistent resource naming
resource "random_pet" "transfer" {
  count  = var.enable_transfer_server ? 1 : 0
  prefix = "anycompany-repairs"
  length = 2
}

################################################################################
# S3 Bucket for Transfer Family
################################################################################

# Create S3 bucket for SFTP file uploads
module "s3_bucket_transfer" {
  count  = var.enable_transfer_server ? 1 : 0
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v5.0.0"

  bucket                   = "${random_pet.transfer[0].id}-claims-files"
  force_destroy            = true
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning = {
    enabled = false
  }

  tags = merge(var.tags, {
    Environment = "Dev"
    Project     = "File Transfer"
    Purpose     = "SFTP Upload Storage"
  })
}

# IAM Role for Transfer Family Session
resource "aws_iam_role" "transfer_session" {
  count = var.enable_transfer_server ? 1 : 0

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


}

# IAM Policy for S3 Access
resource "aws_iam_role_policy" "transfer_session_s3" {
  count = var.enable_transfer_server ? 1 : 0

  name = "transfer-session-s3-access"
  role = aws_iam_role.transfer_session[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListingOfUserFolder"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = module.s3_bucket_transfer[0].s3_bucket_arn
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
        Resource = "${module.s3_bucket_transfer[0].s3_bucket_arn}/*"
      }
    ]
  })
}

# Custom IDP Solution Module
module "transfer_custom_idp" {
  count  = var.enable_custom_idp ? 1 : 0
  source = "git::https://github.com/aws-ia/terraform-aws-transfer-family.git//modules/transfer-custom-idp-solution?ref=v0.4.1"

  name_prefix = "transferidp"
  force_build = false

  use_vpc       = false
  provision_api = false

  codebuild_compute_type = "BUILD_GENERAL1_LARGE"

}

# Populate identity providers table with Cognito user pool details
resource "aws_dynamodb_table_item" "cognito_provider" {
  count = var.enable_custom_idp && var.enable_cognito ? 1 : 0

  table_name = module.transfer_custom_idp[0].identity_providers_table_name
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
          S = module.cognito[0].app_client_id
        }
        cognito_user_pool_region = {
          S = data.aws_region.current.id
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

# Create user record for AnyCompany Auto Repair
resource "aws_dynamodb_table_item" "anycompany_repair_record" {
  count = var.enable_custom_idp && var.enable_transfer_server ? 1 : 0

  table_name = module.transfer_custom_idp[0].users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.transfer_custom_idp]

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
                  S = "/${module.s3_bucket_transfer[0].s3_bucket_id}"
                }
              }
            }
          ]
        }
        HomeDirectoryType = {
          S = "LOGICAL"
        }
        Role = {
          S = aws_iam_role.transfer_session[0].arn
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

# Transfer Family Server Module
module "transfer_server" {
  count = var.enable_transfer_server && var.enable_custom_idp ? 1 : 0

  source = "git::https://github.com/aws-ia/terraform-aws-transfer-family.git//modules/transfer-server?ref=v0.4.0"

  # Server Configuration
  server_name   = "anycompany-insurance-sftp"
  domain        = "S3"
  endpoint_type = "PUBLIC"
  protocols     = ["SFTP"]

  # Custom Identity Provider (Lambda)
  identity_provider      = "AWS_LAMBDA"
  lambda_function_arn    = module.transfer_custom_idp[0].lambda_function_arn
  lambda_invocation_role = null # Optional: IAM role for Lambda invocation

  # Logging
  enable_logging = false # Set to true to enable CloudWatch logging

  # Security Policy
  security_policy_name = "TransferSecurityPolicy-2024-01"

  # Tags
  tags = {
    Name        = "SFTP Server"
    Environment = "Dev"
    Project     = "File Transfer"
    ManagedBy   = "Terraform"
  }
}

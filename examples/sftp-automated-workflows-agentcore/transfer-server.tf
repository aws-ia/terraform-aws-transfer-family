################################################################################
# Transfer Server
# Components: Transfer Family Server, S3 Bucket, User → IDP DynamoDB record
#
# The Custom IDP Lambda (module.transfer_custom_idp) and the Cognito → IDP
# provider record (aws_dynamodb_table_item.cognito_provider) are declared in
# foundation.tf. This file wires the Transfer Family Server to that
# pre-existing IDP when enable_transfer_server = true.
################################################################################

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
# Step 1: Transfer Family Server
################################################################################

# Create Transfer Family SFTP server with Custom IdP authentication
module "transfer_server" {
  count = var.enable_transfer_server && var.enable_custom_idp ? 1 : 0

  source = "../../modules/transfer-server"

  server_name          = "anycompany-insurance-sftp"
  domain               = "S3"
  endpoint_type        = "PUBLIC"
  protocols            = ["SFTP"]
  security_policy_name = "TransferSecurityPolicy-2025-03"

  # Configure server to use the Custom IdP Lambda for authentication
  identity_provider   = "AWS_LAMBDA"
  lambda_function_arn = module.transfer_custom_idp[0].lambda_function_arn

  tags = var.tags
}


################################################################################
# Step 2: Custom IDP Solution
################################################################################

# Deploy Custom IdP Lambda and DynamoDB tables for Transfer Family authentication
module "transfer_custom_idp" {
  count  = var.enable_custom_idp ? 1 : 0
  source = "../../modules/transfer-custom-idp-solution"

  name_prefix = "transferidp"

  # VPC attachment allows connecting to private identity providers (e.g. Active Directory)
  use_vpc = false

  # Optional API Gateway endpoint for use with AWS WAF to filter authentication requests
  provision_api = false

  # Override default BUILD_GENERAL1_SMALL for faster Lambda dependency builds
  codebuild_compute_type = "BUILD_GENERAL1_LARGE"
}

################################################################################
# Step 3: Configure Cognito Identity Provider and User in Custom IdP
################################################################################

# Create user record for AnyCompany Auto Repair assigned to the "cognito_pool" provider
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
        # Logical directory mapping from server root to the claims-files S3 bucket
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
        # IAM role governing S3 read/write access for this session
        Role = {
          S = aws_iam_role.transfer_session[0].arn
        }
      }
    }
    # Source IP allow list for authentication requests
    ipv4_allow_list = {
      SS = [
        "0.0.0.0/0"
      ]
    }
  })
}

# Register Cognito user pool as an identity provider in the Custom IdP solution
resource "aws_dynamodb_table_item" "cognito_provider" {
  count = var.enable_custom_idp && var.enable_cognito ? 1 : 0

  table_name = module.transfer_custom_idp[0].identity_providers_table_name
  hash_key   = "provider"

  depends_on = [module.transfer_custom_idp]

  item = jsonencode({
    provider = {
      # Provider name referenced by user records in the users table
      S = "cognito_pool"
    }
    public_key_support = {
      BOOL = false
    }
    # Cognito-specific configuration: app client ID and region
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
    # Identity provider module used to handle authentication requests
    module = {
      S = "cognito"
    }
  })
}

################################################################################
# Step 4: S3 Bucket for Transfer Family
################################################################################

# Create S3 bucket for SFTP file uploads (repair claims)
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

  tags = var.tags
}

# Create IAM role assumed by Transfer Family to access S3 on behalf of users
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

# Grant Transfer Family session role read/write access to the claims S3 bucket
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

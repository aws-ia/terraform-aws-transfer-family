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
# Step 1: Deploy Custom IDP Solution
################################################################################

# Custom IDP Solution Module
module "transfer_custom_idp" {
  count  = var.enable_custom_idp ? 1 : 0
  source = "git::https://github.com/aws-ia/terraform-aws-transfer-family.git//modules/transfer-custom-idp-solution?ref=v0.4.1"

  # All provisioned resources will use this prefix
  name_prefix = "transferidp" 

  # The Custom IdP Lambda can be attached to a VPC to connect with private 
  # identity providers such as Active Directory
  use_vpc       = false

  # Optionally, deploy an API Gateway API to use with Transfer Family instead of
  # Lambda. This is useful for using AWS Web Application Firewall (WAF) to filter
  # filter authentication requests.
  provision_api = false

  # The module automatically builds the Lambda function dependencies with 
  # CodeBuild. The default compute type is BUILD_GENERAL1_SMALL
  codebuild_compute_type = "BUILD_GENERAL1_LARGE"

}

################################################################################
# Step 2: Transfer Family Server
################################################################################

# Transfer Family Server Module
module "transfer_server" {
  count = var.enable_transfer_server && var.enable_custom_idp ? 1 : 0

  source = "git::https://github.com/aws-ia/terraform-aws-transfer-family.git//modules/transfer-server?ref=v0.4.0"

  # Server Configuration
  server_name   = "anycompany-insurance-sftp"

  # Transfer Family supports "S3" and "EFS" storage domains
  domain        = "S3"

  # The Transfer Family server endpoint can be public or VPC-attached
  endpoint_type = "PUBLIC"
  protocols     = ["SFTP"]

  # These attributes configure the server to use the Custom IdP solution
  identity_provider      = "AWS_LAMBDA"
  lambda_function_arn    = module.transfer_custom_idp[0].lambda_function_arn

  # Tags
  tags = var.tags
}

################################################################################
# Step 3: Configure User and Identity Provider Records
################################################################################

# Populate identity providers table with Cognito user pool details.
resource "aws_dynamodb_table_item" "cognito_provider" {
  count = var.enable_custom_idp && var.enable_cognito ? 1 : 0

  table_name = module.transfer_custom_idp[0].identity_providers_table_name
  hash_key   = "provider"

  depends_on = [module.transfer_custom_idp]

  item = jsonencode({
    provider = {
      # The provider name is referenced in the users table, to assign users.
      S = "cognito_pool"
    }
    public_key_support = {
      BOOL = false
    }
    # Identity providers have specific configuration attributes. In this case,
    # The cognito user pool's app client ID and region are required.
    config = {
      M = {
        cognito_client_id = {
          S = module.cognito[0].app_client_id
        }
        cognito_user_pool_region = {
          S = data.aws_region.current.id
        }
        mfa = {
          # Multi-factor authentication is supported with some providers
          BOOL = false
        }
      }
    }
    # The module field defines which identity provider module will be used
    # to handle authentication requests. 
    module = {
      S = "cognito"
    }
  })
}

# Create user record for AnyCompany Auto Repair and assign to the "cognito_pool" provider
resource "aws_dynamodb_table_item" "anycompany_repair_record" {
  count = var.enable_custom_idp && var.enable_transfer_server ? 1 : 0

  table_name = module.transfer_custom_idp[0].users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.transfer_custom_idp]

  item = jsonencode({
    # The user record defines what identity provider the user is associated with and 
    # connfigures the session.
    user = {
      S = var.cognito_username
    }
    identity_provider_key = {
      S = "cognito_pool"
    }
    # 
    config = {
      M = {
        # In Transfer Family servers, directories can be logically mapped to S3 buckets and paths
        HomeDirectoryDetails = {
          L = [
            {
              # This entry maps the root "/" on the server to the "claims-files" buckets
              # where repair claims are uploaded 
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

        # Transfer Family uses an IAM role to access files in S3. The IAM policy determines
        # Read/Write access to buckets, regardless of directory mappings above. 
        Role = {
          S = aws_iam_role.transfer_session[0].arn
        }
      }
    }
    # Optionally, an IP allow list can be used to control the source IPs a user is
    # allowed to authenticate from.
    ipv4_allow_list = {
      SS = [
        "0.0.0.0/0"
      ]
    }
  })
}

################################################################################
# Step 4: S3 Bucket for Transfer Family
################################################################################

# Create S3 bucket for SFTP file uploads using the s3-bucket module
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

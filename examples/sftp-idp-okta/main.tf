provider "aws" {
  region = var.aws_region
}

provider "okta" {
  org_name  = var.okta_org_name
  base_url  = var.okta_base_url
  api_token = var.okta_api_token
}

# Alternative: Use full org_url if above doesn't work
# provider "okta" {
#   org_url   = "https://${var.okta_domain}"
#   api_token = var.okta_api_token
# }

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
  
  # Okta configuration
  okta_domain           = var.okta_domain
  okta_client_id        = var.okta_client_id
  okta_user_email       = data.okta_user.sftp_user.email
  
  # List of Transfer Family users with their entitlements
  transfer_users = [
    {
      username              = data.okta_user.sftp_user.email
      identity_provider_key = local.okta_domain
      role_arn              = aws_iam_role.transfer_session.arn
      home_directory_mappings = [
        {
          entry  = "/"
          target = "/${module.s3_bucket.s3_bucket_id}"
        }
      ]
    },
    {
      username              = "$default$"
      identity_provider_key = local.okta_domain
      role_arn              = aws_iam_role.transfer_session.arn
      home_directory_mappings = [
        {
          entry  = "/home"
          target = "/${module.s3_bucket.s3_bucket_id}/users/$${transfer:UserName}"
        }
      ]
      ipv4_allow_list = ["0.0.0.0/0"]
    }
  ]
}

###################################################################
# Custom IDP module
###################################################################
module "custom_idp" {
  source = "../../modules/transfer-custom-idp-solution"

  name_prefix                   = var.name_prefix
  users_table_name              = ""
  identity_providers_table_name = ""
  create_vpc                    = false
  use_vpc                       = false
  provision_api                 = var.provision_api
  enable_deletion_protection    = var.enable_deletion_protection
  
  tags = var.tags
}

###################################################################
# Transfer Server
###################################################################
module "transfer_server" {
  source = "../../modules/transfer-server"
  
  domain                      = "S3"
  protocols                   = ["SFTP"]
  endpoint_type               = "PUBLIC"
  server_name                 = local.server_name
  identity_provider           = var.provision_api ? "API_GATEWAY" : "AWS_LAMBDA"
  lambda_function_arn         = var.provision_api ? null : module.custom_idp.lambda_function_arn
  api_gateway_url             = var.provision_api ? module.custom_idp.api_gateway_url : null
  api_gateway_invocation_role = var.provision_api ? module.custom_idp.api_gateway_role_arn : null
  security_policy_name        = "TransferSecurityPolicy-2024-01"
  enable_logging              = true
  
  tags = var.tags
}

###################################################################
# DynamoDB Configuration
###################################################################

# Populate identity providers table with Okta configuration
resource "aws_dynamodb_table_item" "okta_provider" {
  table_name = module.custom_idp.identity_providers_table_name
  hash_key   = "provider"

  depends_on = [module.custom_idp]

  item = jsonencode({
    provider = {
      S = local.okta_domain
    }
    public_key_support = {
      BOOL = false
    }
    config = {
      M = {
        okta_domain = {
          S = local.okta_domain
        }
        okta_app_client_id = {
          S = local.okta_client_id
        }
        okta_redirect_uri = {
          S = "awstransfer:/callback"
        }
        mfa = {
          BOOL = false
        }
      }
    }
    module = {
      S = "okta"
    }
  })
}

# Create user records for Transfer Family users
resource "aws_dynamodb_table_item" "transfer_user_records" {
  for_each = { for user in local.transfer_users : user.username => user }

  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.custom_idp]

  item = jsonencode(merge(
    {
      user = {
        S = lower(each.value.username)
      }
      identity_provider_key = {
        S = each.value.identity_provider_key
      }
      config = {
        M = {
          HomeDirectoryDetails = {
            L = [
              for mapping in each.value.home_directory_mappings : {
                M = {
                  Entry = {
                    S = mapping.entry
                  }
                  Target = {
                    S = mapping.target
                  }
                }
              }
            ]
          }
          HomeDirectoryType = {
            S = "LOGICAL"
          }
          Role = {
            S = each.value.role_arn
          }
        }
      }
    },
    can(each.value.ipv4_allow_list) ? {
      ipv4_allow_list = {
        SS = each.value.ipv4_allow_list
      }
    } : {}
  ))
}

###################################################################
# Okta User Management
###################################################################

# Data source to retrieve existing Okta user
data "okta_user" "sftp_user" {
  user_id = var.okta_user_id
}

# Assign user to the Okta SFTP application
resource "okta_app_user" "sftp_app_user" {
  count    = var.okta_app_id != "" ? 1 : 0
  app_id   = var.okta_app_id
  user_id  = data.okta_user.sftp_user.id
  username = data.okta_user.sftp_user.email
}

###################################################################
# S3 Bucket for Transfer Family
###################################################################
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "${random_pet.name.id}-${random_id.suffix.hex}-transfer-files"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy           = true

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
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = module.s3_bucket.s3_bucket_arn
      },
      {
        Sid    = "HomeDirObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectTagging",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObjectVersion",
          "s3:GetObjectVersionTagging",
          "s3:GetObjectACL",
          "s3:PutObjectACL"
        ]
        Resource = "${module.s3_bucket.s3_bucket_arn}/*"
      }
    ]
  })
}

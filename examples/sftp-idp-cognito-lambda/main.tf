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
  
  # Determine whether to use existing Cognito pool or create new one
  use_existing_cognito = var.existing_cognito_user_pool_id != null
  cognito_pool_id      = local.use_existing_cognito ? var.existing_cognito_user_pool_id : aws_cognito_user_pool.transfer_users[0].id
  cognito_client_id    = local.use_existing_cognito ? var.existing_cognito_user_pool_client_id : aws_cognito_user_pool_client.transfer_client[0].id
  cognito_pool_region  = local.use_existing_cognito ? var.existing_cognito_user_pool_region : var.aws_region
  
  # List of Transfer Family users with their entitlements
  # Each user entry is stored in DynamoDB and defines:
  # - username: SFTP login name (or "$default$" for fallback user)
  # - identity_provider_key: Links to Cognito User Pool for authentication
  # - role_arn: IAM role granting S3 access permissions
  # - home_directory_mappings: Virtual-to-physical path mappings for SFTP sessions
  # - ipv4_allow_list: (optional) IP allowlist for connection restrictions
  transfer_users = [
    {
      # Primary Cognito user - no IP restrictions
      username              = var.cognito_username
      identity_provider_key = local.cognito_pool_id
      role_arn              = aws_iam_role.transfer_session.arn
      home_directory_mappings = [
        {
          entry  = "/"
          target = "/${module.s3_bucket.s3_bucket_id}"
        }
      ]
    },
    {
      # Default fallback user with IP restrictions
      username              = "$default$"
      identity_provider_key = local.cognito_pool_id
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
# Provisions: Lambda function, Lambda layer, DynamoDB tables (users & 
# identity providers), S3 bucket for artifacts, CodeBuild project, 
# IAM roles and policies for Lambda execution and Transfer Family invocation
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
# Transfer Server using transfer_server module
# Provisions: AWS Transfer Family SFTP server with public endpoint,
# Lambda-based custom identity provider integration, CloudWatch logging,
# and security policy TransferSecurityPolicy-2024-01
###################################################################
module "transfer_server" {
  source = "../../modules/transfer-server"
  
  domain                      = "S3"
  protocols                   = ["SFTP"]
  endpoint_type               = "PUBLIC"
  server_name                 = local.server_name
  identity_provider           = var.provision_api ? "API_GATEWAY" : "AWS_LAMBDA"
  lambda_function_arn         = var.provision_api ? null : module.custom_idp.lambda_function_arn
  api_gateway_url             = var.provision_api ? module.custom_idp.api_gateway_role_arn : null
  api_gateway_invocation_role = var.provision_api ? module.custom_idp.api_gateway_url : null
  security_policy_name        = "TransferSecurityPolicy-2024-01"
  enable_logging              = true
  
  tags = var.tags
}


###################################################################
# DynamoDB Configuration
# Provisions: DynamoDB table items that configure the identity provider
# (Cognito settings) and user mappings (home directory, IAM role, IP allowlist)
###################################################################

# Populate identity providers table with Cognito user pool details
resource "aws_dynamodb_table_item" "cognito_provider" {
  table_name = module.custom_idp.identity_providers_table_name
  hash_key   = "provider"

  depends_on = [module.custom_idp]

  item = jsonencode({
    provider = {
      S = local.cognito_pool_id
    }
    public_key_support = {
      BOOL = false
    }
    config = {
      M = {
        cognito_client_id = {
          S = local.cognito_client_id
        }
        cognito_user_pool_region = {
          S = local.cognito_pool_region
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

# Create user records for Transfer Family users from the transfer_users list
resource "aws_dynamodb_table_item" "transfer_user_records" {
  for_each = { for user in local.transfer_users : user.username => user }

  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.custom_idp]

  item = jsonencode(merge(
    {
      user = {
        S = lower(each.value.username) # usernames must always be lowercase
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

# Create user record for the Cognito demo user (if not already in transfer_users list)
resource "aws_dynamodb_table_item" "cognito_demo_user" {
  count = contains([for u in local.transfer_users : u.username], var.cognito_username) ? 0 : 1

  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.custom_idp]

  item = jsonencode({
    user = {
      S = lower(var.cognito_username)
    }
    identity_provider_key = {
      S = local.cognito_pool_id
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
# Cognito User Pool (Optional - only created if not using existing pool)
# Provisions: Cognito User Pool with password policy, User Pool Client
# for authentication, Cognito user with auto-generated password, and
# Secrets Manager secret to securely store the password
###################################################################
resource "aws_cognito_user_pool" "transfer_users" {
  count = local.use_existing_cognito ? 0 : 1
  
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
  count = local.use_existing_cognito ? 0 : 1
  
  name         = "${var.name_prefix}-client"
  user_pool_id = aws_cognito_user_pool.transfer_users[0].id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# Generate secure random password for Cognito user
resource "random_password" "cognito_user" {
  count = local.use_existing_cognito ? 0 : 1
  
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

# Create primary Cognito user with generated password
resource "aws_cognito_user" "transfer_user" {
  count = local.use_existing_cognito ? 0 : 1
  
  user_pool_id = aws_cognito_user_pool.transfer_users[0].id
  username     = var.cognito_username

  attributes = {
    email          = var.cognito_user_email
    email_verified = true
  }

  password = random_password.cognito_user[0].result

  lifecycle {
    ignore_changes = [password]
  }
}

# Generate secure random password for second Cognito user
resource "random_password" "cognito_user_default" {
  count = local.use_existing_cognito ? 0 : 1
  
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

# Create second Cognito user to demonstrate $default$ fallback behavior
# This user has no explicit transfer_users record, so will use the $default$ configuration
resource "aws_cognito_user" "transfer_user_default" {
  count = local.use_existing_cognito ? 0 : 1
  
  user_pool_id = aws_cognito_user_pool.transfer_users[0].id
  username     = "user2"

  attributes = {
    email          = "user2@example.com"
    email_verified = true
  }

  password = random_password.cognito_user_default[0].result

  lifecycle {
    ignore_changes = [password]
  }
}

# Store Cognito user passwords securely in Secrets Manager
resource "aws_secretsmanager_secret" "cognito_user_password" {
  count = local.use_existing_cognito ? 0 : 1
  
  #checkov:skip=CKV_AWS_149:Using AWS managed encryption is acceptable for this example
  #checkov:skip=CKV2_AWS_57:Automatic rotation not required for Cognito user passwords
  name_prefix             = "${var.name_prefix}-cognito-passwords-"
  recovery_window_in_days = 0

  tags = var.tags
}

# Store both user passwords in Secrets Manager
resource "aws_secretsmanager_secret_version" "cognito_user_password" {
  count = local.use_existing_cognito ? 0 : 1
  
  secret_id = aws_secretsmanager_secret.cognito_user_password[0].id
  secret_string = jsonencode({
    user1 = {
      username = var.cognito_username
      password = random_password.cognito_user[0].result
    }
    user2 = {
      username = "user2"
      password = random_password.cognito_user_default[0].result
    }
  })
}

###################################################################
# S3 Bucket for Transfer Family
# Provisions: S3 bucket with versioning, encryption (AES256), and public
# access blocking for secure file storage
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
# Provisions: IAM role and policy that grants Transfer Family sessions
# permissions to list buckets and perform object operations (read, write,
# delete) in user-specific S3 directories
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


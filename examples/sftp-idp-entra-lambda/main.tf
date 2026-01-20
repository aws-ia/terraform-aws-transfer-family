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
  provision_api                 = false
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
  
  domain               = "S3"
  protocols            = ["SFTP"]
  endpoint_type        = "PUBLIC"
  server_name          = local.server_name
  identity_provider    = "AWS_LAMBDA"
  lambda_function_arn  = module.custom_idp.lambda_function_arn
  security_policy_name = "TransferSecurityPolicy-2024-01"
  enable_logging       = true
  
  tags = var.tags
}


###################################################################
# DynamoDB Configuration
# Provisions: DynamoDB table items that configure the identity provider
# (Entra settings) and user mappings (home directory, IAM role, IP allowlist)
###################################################################

# Populate identity providers table with Entra ID application details
resource "aws_dynamodb_table_item" "entra_provider" {
  table_name = module.custom_idp.identity_providers_table_name
  hash_key   = "provider"

  depends_on = [module.custom_idp]

  item = jsonencode({
    provider = {
      S = var.entra_provider_name
    }
    config = {
      M = {
        client_id = {
          S = var.entra_client_id
        }
        app_secret_arn = {
          S = aws_secretsmanager_secret_version.entra_client_secret.arn
        }
        authority_url = {
          S = var.entra_authority_url
        }
      }
    }
    module = {
      S = "entra"
    }
  })
}

# Create user record for default Transfer Family user
resource "aws_dynamodb_table_item" "transfer_user_records" {

  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.custom_idp]

  item = jsonencode(merge(
    {
      user = {
        S = "$default$"
      }
      identity_provider_key = {
        S = var.entra_provider_name
      }
      config = {
        M = {
          HomeDirectoryDetails = {
            L = [
              {
                M = {
                  Entry = {
                    S = "/home"
                  }
                  Target = {
                    S = "/${module.s3_bucket.s3_bucket_id}/users/$${transfer:UserName}"
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
        SS = ["0.0.0.0/0"]
      }
    }
  ))
}

# Create user records for the Entra users
resource "aws_dynamodb_table_item" "entra_users" {
  for_each = toset(var.entra_usernames)

  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.custom_idp]

  item = jsonencode({
    user = {
      S = lower(each.value)
    }
    identity_provider_key = {
      S = var.entra_provider_name
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

# Store Entra client secret securely in Secrets Manager
resource "aws_secretsmanager_secret" "entra_client_secret" {
  
  name_prefix             = "${var.name_prefix}-transfer-idp-entra-client-secret"
  recovery_window_in_days = 0

  tags = var.tags
}

# Store Entra client secret securely in Secrets Manager
resource "aws_secretsmanager_secret_version" "entra_client_secret" {
  
  secret_id = aws_secretsmanager_secret.entra_client_secret.id
  secret_string = var.entra_client_secret
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


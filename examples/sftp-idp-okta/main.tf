provider "aws" {
  region = var.aws_region
}

######################################
# Defaults and Locals
######################################

resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 2
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  server_name = "transfer-server-${random_pet.name.id}"

  # Okta configuration
  okta_domain        = var.okta_domain
  okta_app_client_id = var.okta_app_client_id
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
          S = local.okta_app_client_id
        }
        okta_redirect_uri = {
          S = "awstransfer:/callback"
        }
        mfa = {
          BOOL = var.okta_mfa_required
        }
        mfa_token_length = {
          N = tostring(var.okta_mfa_token_length)
        }
      }
    }
    module = {
      S = "okta"
    }
  })
}

# Create user record for the default Transfer Family user (catch-all).
# Any authenticated user not explicitly listed lands in their own folder.
resource "aws_dynamodb_table_item" "default_user" {
  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.custom_idp]

  item = jsonencode({
    user = {
      S = "$default$"
    }
    identity_provider_key = {
      S = local.okta_domain
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
      SS = var.default_user_ipv4_allow_list
    }
  })
}

# Create user records for the Okta users. Each listed user gets their own
# home directory at the bucket root under their username.
resource "aws_dynamodb_table_item" "okta_users" {
  for_each = toset(var.okta_users)

  table_name = module.custom_idp.users_table_name
  hash_key   = "user"
  range_key  = "identity_provider_key"

  depends_on = [module.custom_idp]

  item = jsonencode({
    user = {
      S = lower(each.value)
    }
    identity_provider_key = {
      S = local.okta_domain
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
  })
}

###################################################################
# S3 Bucket for Transfer Family
###################################################################
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

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
        sse_algorithm     = var.s3_encryption_algorithm
        kms_master_key_id = var.s3_kms_key_id
      }
    }
  }

  tags = var.tags
}

###################################################################
# IAM Role for Transfer Family Session
###################################################################
data "aws_iam_policy_document" "transfer_session_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "transfer_session" {
  name               = "${var.name_prefix}-transfer-session-role"
  assume_role_policy = data.aws_iam_policy_document.transfer_session_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "transfer_session_s3" {
  statement {
    sid    = "AllowListingOfUserFolder"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [module.s3_bucket.s3_bucket_arn]
  }

  statement {
    sid    = "HomeDirObjectAccess"
    effect = "Allow"

    actions = [
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

    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "transfer_session_s3" {
  name   = "transfer-session-s3-access"
  role   = aws_iam_role.transfer_session.id
  policy = data.aws_iam_policy_document.transfer_session_s3.json
}

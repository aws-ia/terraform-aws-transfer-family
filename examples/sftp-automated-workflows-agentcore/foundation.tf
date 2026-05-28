################################################################################
# Identity Foundation + Custom IDP
# Components: IAM Identity Center, S3 Access Grants, Cognito, Transfer Custom IDP
################################################################################

################################################################################
# Data Sources (shared across files)
################################################################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# IAM Identity Center
################################################################################

# Create IAM Identity Center instance for centralized identity management
resource "awscc_sso_instance" "main" {
  count = var.enable_identity_center ? 1 : 0

  name = "default"
  tags = [
    for key, value in var.tags : {
      key   = key
      value = value
    }
  ]
}

# Store Identity Center IDs for use across resources
locals {
  identity_store_id = var.enable_identity_center ? awscc_sso_instance.main[0].identity_store_id : null
  sso_instance_arn  = var.enable_identity_center ? awscc_sso_instance.main[0].instance_arn : null
}

################################################################################
# Identity Center Groups
################################################################################


# Create Claims Reviewers group for users with review permissions
resource "aws_identitystore_group" "claims_reviewers" {
  count = var.enable_identity_center ? 1 : 0

  identity_store_id = local.identity_store_id
  display_name      = "Claims Reviewers"
  description       = "Group for claims reviewers"
}

# Create Claims Admins group for users with administrative permissions
resource "aws_identitystore_group" "claims_admins" {
  count = var.enable_identity_center ? 1 : 0

  identity_store_id = local.identity_store_id
  display_name      = "Claims Admins"
  description       = "Group for claims administrators"
}

################################################################################
# Identity Center Users
################################################################################

# Create Claims Reviewer user account
resource "aws_identitystore_user" "claims_reviewer" {
  count = var.enable_identity_center ? 1 : 0

  identity_store_id = local.identity_store_id
  display_name      = "Claims Reviewer"
  user_name         = "claims-reviewer"

  name {
    given_name  = "Claims"
    family_name = "Reviewer"
  }

  emails {
    value   = "claims-reviewer@anycompany-insurance.com"
    primary = true
  }
}

# Create Claims Administrator user account
resource "aws_identitystore_user" "claims_administrator" {
  count = var.enable_identity_center ? 1 : 0

  identity_store_id = local.identity_store_id
  display_name      = "Claims Administrator"
  user_name         = "claims-administrator"

  name {
    given_name  = "Claims"
    family_name = "Administrator"
  }

  emails {
    value   = "claims-administrator@anycompany-insurance.com"
    primary = true
  }
}

################################################################################
# Group Memberships
################################################################################

# Add Claims Reviewer to Claims Reviewers group
resource "aws_identitystore_group_membership" "claims_reviewer_to_reviewers" {
  count = var.enable_identity_center ? 1 : 0

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.claims_reviewers[0].group_id
  member_id         = aws_identitystore_user.claims_reviewer[0].user_id
}

# Add Claims Administrator to Claims Admins group
resource "aws_identitystore_group_membership" "claims_administrator_to_admins" {
  count = var.enable_identity_center ? 1 : 0

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.claims_admins[0].group_id
  member_id         = aws_identitystore_user.claims_administrator[0].user_id
}

################################################################################
# S3 Access Grants
################################################################################

# Create S3 Access Grants instance for fine-grained S3 access control
resource "aws_s3control_access_grants_instance" "main" {
  count = var.enable_s3_access_grants ? 1 : 0

  identity_center_arn = local.sso_instance_arn

  tags = var.tags
}

################################################################################
# Cognito User Pool for External Users
################################################################################

# Generate random suffix for globally unique Cognito domain
resource "random_id" "cognito_domain_suffix" {
  count       = var.enable_cognito ? 1 : 0
  byte_length = 3
}

# Create Cognito User Pool with hosted UI for external user authentication
module "cognito" {
  count  = var.enable_cognito ? 1 : 0
  source = "./modules/cognito-hosted-ui"

  user_pool_name        = "anycompany-insurance-external-pool"
  domain_prefix         = "${var.cognito_domain_prefix}-${random_id.cognito_domain_suffix[0].hex}"
  app_client_name       = "anycompany-insurance-client"
  branding_settings     = "${path.root}/cognito-branding.json"
  landing_page_template = "${path.root}/landing.html"
  create_landing_page   = true

  tags = var.tags
}

# Create external user account in Cognito for AnyCompany Auto Repair
resource "aws_cognito_user" "anycompany" {
  count = var.enable_cognito ? 1 : 0

  user_pool_id = module.cognito[0].user_pool_id
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

# Generate secure random password for Cognito user
resource "random_password" "cognito_user" {
  count = var.enable_cognito ? 1 : 0

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

# Store Cognito user password securely in Secrets Manager
resource "aws_secretsmanager_secret" "cognito_user_password" {
  #checkov:skip=CKV_AWS_149: "Using AWS managed encryption is acceptable for this example"
  #checkov:skip=CKV2_AWS_57: "Automatic rotation not required for Cognito user passwords"
  count = var.enable_cognito ? 1 : 0

  name_prefix             = "cognito-user-password-"
  recovery_window_in_days = 0
}

# Store password value in Secrets Manager
resource "aws_secretsmanager_secret_version" "cognito_user_password" {
  count = var.enable_cognito ? 1 : 0

  secret_id = aws_secretsmanager_secret.cognito_user_password[0].id
  secret_string = jsonencode({
    username = var.cognito_username
    password = random_password.cognito_user[0].result
  })
}

################################################################################
# Custom IDP Solution
################################################################################

# Custom IDP Solution Module
module "transfer_custom_idp" {
  count  = var.enable_custom_idp ? 1 : 0
  source = "git::https://github.com/aws-ia/terraform-aws-transfer-family.git//modules/transfer-custom-idp-solution?ref=v0.6.0"

  # All provisioned resources will use this prefix
  name_prefix = "transferidp"

  # The Custom IdP Lambda can be attached to a VPC to connect with private ***
  # identity providers such as Active Directory
  use_vpc = false

  # Optionally, deploy an API Gateway API to use with Transfer Family instead of
  # Lambda. This is useful for using AWS Web Application Firewall (WAF) to filter
  # filter authentication requests.
  provision_api = false

  # The module automatically builds the Lambda function dependencies with
  # CodeBuild. The default compute type is BUILD_GENERAL1_SMALL
  codebuild_compute_type = "BUILD_GENERAL1_LARGE"

}

################################################################################
# Cognito → Custom IDP Provider Record
################################################################################

# Populate identity providers table with Cognito user pool details.
resource "aws_dynamodb_table_item" "cognito_provider" {
  count = var.enable_custom_idp && var.enable_cognito ? 1 : 0

  table_name = module.transfer_custom_idp[0].identity_providers_table_name
  hash_key   = "provider"

  depends_on = [module.transfer_custom_idp]

  item = jsonencode({
    provider = {
      # The provider name is referenced in the users table, to assign users. ***
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

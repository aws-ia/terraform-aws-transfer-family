################################################################################
# Stage 0: Identity Foundation
# Components: IAM Identity Center, S3 Access Grants, Cognito
################################################################################

################################################################################
# Cognito Variables
################################################################################

variable "cognito_username" {
  description = "Username for the AnyCompany Auto Repair user"
  type        = string
  default     = "anycompany-repairs"
}

variable "cognito_user_email" {
  description = "Email address for the AnyCompany Auto Repair user"
  type        = string
  default     = "repairs@anycompany.example.com"
}

variable "cognito_domain_prefix" {
  description = "Domain prefix for Cognito hosted UI"
  type        = string
  default     = "anycompany-insurance"
}

################################################################################
# IAM Identity Center
################################################################################

# Create IAM Identity Center instance for centralized identity management
resource "awscc_sso_instance" "main" {
  count = var.enable_identity_center ? 1 : 0

  name = "default"
  tags = [
    {
      key   = "ManagedBy"
      value = "Terraform"
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

# Create Claims Team group for all claims processing members
resource "aws_identitystore_group" "claims_team" {
  count = var.enable_identity_center ? 1 : 0

  identity_store_id = local.identity_store_id
  display_name      = "Claims Team"
  description       = "Group for claims processing team members"
}

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

# Add Claims Reviewer to Claims Team group
resource "aws_identitystore_group_membership" "claims_reviewer_membership" {
  count = var.enable_identity_center ? 1 : 0

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.claims_team[0].group_id
  member_id         = aws_identitystore_user.claims_reviewer[0].user_id
}

# Add Claims Administrator to Claims Team group
resource "aws_identitystore_group_membership" "claims_administrator_membership" {
  count = var.enable_identity_center ? 1 : 0

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.claims_team[0].group_id
  member_id         = aws_identitystore_user.claims_administrator[0].user_id
}

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

  tags = {
    Environment = "Dev"
    ManagedBy   = "Terraform"
    Project     = "File Transfer"
  }
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

  tags = {
    Name      = "AnyCompany Insurance"
    ManagedBy = "Terraform"
  }
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

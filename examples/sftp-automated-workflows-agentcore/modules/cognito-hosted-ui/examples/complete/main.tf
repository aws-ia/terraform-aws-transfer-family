terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Cognito Hosted UI with Landing Page
module "cognito" {
  source = "../../"

  user_pool_name        = var.user_pool_name
  domain_prefix         = var.domain_prefix
  app_client_name       = var.app_client_name
  branding_settings     = var.branding_settings != null ? "${path.module}/${var.branding_settings}" : null
  landing_page_template = var.landing_page_template != null ? "${path.module}/${var.landing_page_template}" : null
  create_landing_page   = var.create_landing_page

  password_policy = var.password_policy

  tags = var.tags
}

# Example: Create a test user
resource "random_password" "test_user" {
  length  = 16
  special = true
  numeric = true
  upper   = true
  lower   = true
}

resource "aws_cognito_user" "test" {
  count = var.create_test_user ? 1 : 0

  user_pool_id = module.cognito.user_pool_id
  username     = var.test_username

  attributes = {
    email          = var.test_user_email
    email_verified = true
  }

  password = random_password.test_user.result

  lifecycle {
    ignore_changes = [password]
  }
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "test_user_password" {
  count = var.create_test_user ? 1 : 0

  name_prefix             = "cognito-test-user-password-"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "test_user_password" {
  count = var.create_test_user ? 1 : 0

  secret_id = aws_secretsmanager_secret.test_user_password[0].id
  secret_string = jsonencode({
    username = var.test_username
    password = random_password.test_user.result
  })
}

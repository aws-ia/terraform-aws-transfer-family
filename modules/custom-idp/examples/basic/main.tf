# Basic usage example for AWS Transfer Family Custom IdP Terraform module
# This example demonstrates the minimal configuration required to deploy the custom IdP solution

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Deploy the Custom IdP module with minimal configuration
module "transfer_custom_idp" {
  source = "../../"

  # Required: Prefix for all resource names
  name_prefix = var.name_prefix

  # Basic configuration - Lambda will run without VPC attachment
  use_vpc = false

  # Basic logging configuration
  log_level               = "INFO"
  log_retention_in_days   = 14

  # DynamoDB configuration - create new tables
  dynamodb_billing_mode = "PAY_PER_REQUEST"

  # Basic Lambda configuration
  lambda_timeout     = 45
  lambda_memory_size = 1024

  # Identity provider configuration
  user_name_delimiter = "@@"

  # Disable optional features for basic deployment
  enable_api_gateway                    = false
  enable_secrets_manager_permissions    = false
  enable_xray_tracing                  = false
  enable_point_in_time_recovery        = true

  # Tags
  tags = var.tags
}

# Create an AWS Transfer Family server using the Lambda integration
resource "aws_transfer_server" "example" {
  identity_provider_type = "LAMBDA"
  function              = module.transfer_custom_idp.lambda_function_arn
  
  protocols = ["SFTP"]
  
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-transfer-server"
  })
}
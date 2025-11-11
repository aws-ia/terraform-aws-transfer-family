terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create the custom identity provider module with API Gateway
module "custom_idp" {
  source = "../../modules/custom-idps"

  # Enable API Gateway integration
  use_api_gateway = true
  
  # DynamoDB table names
  users_table_name             = "sftp-users"
  identity_providers_table_name = "sftp-identity-providers"
  
  # Cognito configuration
  cognito_user_pool_name   = var.cognito_user_pool_name
  cognito_user_pool_client = var.cognito_user_pool_client

  tags = var.tags
}

# Create Transfer Family server with API Gateway URL as identity provider
resource "aws_transfer_server" "sftp_server" {
  identity_provider_type = "API_GATEWAY"
  url                   = module.custom_idp.api_gateway_url
  invocation_role       = module.custom_idp.transfer_invocation_role_arn
  
  protocols     = ["SFTP"]
  domain        = "S3"
  endpoint_type = "PUBLIC"

  tags = var.tags
}

# Create S3 bucket for file storage
resource "aws_s3_bucket" "sftp_storage" {
  bucket = "${var.bucket_prefix}-sftp-storage-${random_id.bucket_suffix.hex}"

  tags = var.tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "sftp_storage" {
  bucket = aws_s3_bucket.sftp_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sftp_storage" {
  bucket = aws_s3_bucket.sftp_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

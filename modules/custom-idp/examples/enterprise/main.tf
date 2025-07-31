# Enterprise usage example for AWS Transfer Family Custom IdP Terraform module
# This example demonstrates advanced configuration with all enterprise features enabled

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

# Data sources for existing infrastructure
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  id    = var.vpc_id
}

data "aws_subnets" "private" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    Type = "Private"
  }
}

data "aws_security_group" "lambda" {
  count = var.use_existing_vpc ? 1 : 0
  name  = var.lambda_security_group_name
  vpc_id = var.vpc_id
}

# KMS key for encryption
resource "aws_kms_key" "transfer_idp" {
  count = var.create_kms_key ? 1 : 0
  
  description             = "KMS key for Transfer Family Custom IdP encryption"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-kms-key"
  })
}

resource "aws_kms_alias" "transfer_idp" {
  count         = var.create_kms_key ? 1 : 0
  name          = "alias/${var.name_prefix}-transfer-idp"
  target_key_id = aws_kms_key.transfer_idp[0].key_id
}

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Deploy the Custom IdP module with enterprise configuration
module "transfer_custom_idp" {
  source = "../../"

  # Required: Prefix for all resource names
  name_prefix = var.name_prefix

  # VPC Configuration - use existing VPC and security groups
  use_vpc            = var.use_existing_vpc
  vpc_id             = var.use_existing_vpc ? var.vpc_id : null
  subnet_ids         = var.use_existing_vpc ? data.aws_subnets.private[0].ids : []
  security_group_ids = var.use_existing_vpc ? [data.aws_security_group.lambda[0].id] : []

  # Enterprise Lambda configuration
  lambda_timeout     = var.lambda_timeout
  lambda_memory_size = var.lambda_memory_size

  # Identity provider configuration
  user_name_delimiter = var.user_name_delimiter

  # Enable all enterprise features
  enable_api_gateway                    = var.enable_api_gateway
  enable_secrets_manager_permissions    = true
  enable_xray_tracing                  = var.enable_xray_tracing
  enable_point_in_time_recovery        = true

  # DynamoDB configuration with existing tables support
  existing_users_table_name             = var.existing_users_table_name
  existing_identity_providers_table_name = var.existing_identity_providers_table_name
  dynamodb_billing_mode                 = var.dynamodb_billing_mode

  # Security configuration with KMS encryption
  kms_key_id = var.create_kms_key ? aws_kms_key.transfer_idp[0].arn : var.existing_kms_key_id

  # Enhanced logging configuration
  log_level               = var.log_level
  log_retention_in_days   = var.log_retention_in_days

  # Enterprise tags
  tags = merge(var.tags, {
    Environment = var.environment
    Compliance  = "SOC2"
    Backup      = "Required"
  })
}

# Create AWS Transfer Family server with API Gateway integration (if enabled)
resource "aws_transfer_server" "enterprise" {
  count = var.enable_api_gateway ? 1 : 0
  
  identity_provider_type = "API_GATEWAY"
  url                   = module.transfer_custom_idp.api_gateway_url
  invocation_role       = module.transfer_custom_idp.api_gateway_execution_role_arn
  
  protocols = var.transfer_protocols
  
  # Enterprise security features
  security_policy_name = var.transfer_security_policy
  
  # Structured logging
  structured_log_destinations = var.enable_structured_logging ? [aws_cloudwatch_log_group.transfer_logs[0].arn] : []
  
  # Domain configuration for custom domain
  domain = var.custom_domain_enabled ? "EFS" : "S3"
  
  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-transfer-server-api"
    Integration = "API_Gateway"
  })
}

# Create AWS Transfer Family server with Lambda integration (if API Gateway disabled)
resource "aws_transfer_server" "enterprise_lambda" {
  count = var.enable_api_gateway ? 0 : 1
  
  identity_provider_type = "LAMBDA"
  function              = module.transfer_custom_idp.lambda_function_arn
  
  protocols = var.transfer_protocols
  
  # Enterprise security features
  security_policy_name = var.transfer_security_policy
  
  # Structured logging
  structured_log_destinations = var.enable_structured_logging ? [aws_cloudwatch_log_group.transfer_logs[0].arn] : []
  
  # Domain configuration
  domain = var.custom_domain_enabled ? "EFS" : "S3"
  
  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-transfer-server-lambda"
    Integration = "Lambda"
  })
}

# CloudWatch log group for Transfer Family logs
resource "aws_cloudwatch_log_group" "transfer_logs" {
  count = var.enable_structured_logging ? 1 : 0
  
  name              = "/aws/transfer/${var.name_prefix}"
  retention_in_days = var.log_retention_in_days
  kms_key_id        = var.create_kms_key ? aws_kms_key.transfer_idp[0].arn : var.existing_kms_key_id
  
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-transfer-logs"
  })
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${var.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    FunctionName = module.transfer_custom_idp.lambda_function_name
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${var.name_prefix}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "30000"  # 30 seconds
  alarm_description   = "This metric monitors lambda duration"
  alarm_actions       = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    FunctionName = module.transfer_custom_idp.lambda_function_name
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${var.name_prefix}-dynamodb-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors DynamoDB throttles"
  alarm_actions       = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    TableName = module.transfer_custom_idp.users_table_name
  }
  
  tags = var.tags
}
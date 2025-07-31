# Variables for enterprise usage example

# Basic Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "enterprise-transfer-idp"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.name_prefix))
    error_message = "Name prefix must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["production", "staging", "development", "test"], var.environment)
    error_message = "Environment must be one of: production, staging, development, test."
  }
}

# VPC Configuration
variable "use_existing_vpc" {
  description = "Whether to use an existing VPC"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID where Lambda function will be deployed (required if use_existing_vpc is true)"
  type        = string
  default     = null
  validation {
    condition     = var.vpc_id == null || can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier (vpc-xxxxxxxx)."
  }
}

variable "lambda_security_group_name" {
  description = "Name of existing security group for Lambda function"
  type        = string
  default     = "lambda-sg"
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 2048
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

# Identity Provider Configuration
variable "user_name_delimiter" {
  description = "Delimiter for username and identity provider"
  type        = string
  default     = "@@"
  validation {
    condition     = contains(["@", "@@"], var.user_name_delimiter)
    error_message = "User name delimiter must be either '@' or '@@'."
  }
}

# Feature Flags
variable "enable_api_gateway" {
  description = "Whether to create API Gateway for REST-based integration"
  type        = bool
  default     = true
}

variable "enable_xray_tracing" {
  description = "Whether to enable X-Ray tracing"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Whether to create CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "enable_structured_logging" {
  description = "Whether to enable structured logging for Transfer Family"
  type        = bool
  default     = true
}

# DynamoDB Configuration
variable "existing_users_table_name" {
  description = "Name of existing DynamoDB users table (optional)"
  type        = string
  default     = null
}

variable "existing_identity_providers_table_name" {
  description = "Name of existing DynamoDB identity providers table (optional)"
  type        = string
  default     = null
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "DynamoDB billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

# Security Configuration
variable "create_kms_key" {
  description = "Whether to create a new KMS key for encryption"
  type        = bool
  default     = true
}

variable "existing_kms_key_id" {
  description = "ID of existing KMS key for encryption (used if create_kms_key is false)"
  type        = string
  default     = null
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

# Logging Configuration
variable "log_level" {
  description = "Lambda function log level"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["INFO", "DEBUG"], var.log_level)
    error_message = "Log level must be either INFO or DEBUG."
  }
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_in_days)
    error_message = "Log retention must be a valid CloudWatch log retention value."
  }
}

# Transfer Family Configuration
variable "transfer_protocols" {
  description = "List of protocols to enable on Transfer Family server"
  type        = list(string)
  default     = ["SFTP", "FTPS"]
  validation {
    condition = alltrue([
      for protocol in var.transfer_protocols : contains(["SFTP", "FTPS", "FTP"], protocol)
    ])
    error_message = "Transfer protocols must be one or more of: SFTP, FTPS, FTP."
  }
}

variable "transfer_security_policy" {
  description = "Security policy for Transfer Family server"
  type        = string
  default     = "TransferSecurityPolicy-2023-05"
}

variable "custom_domain_enabled" {
  description = "Whether to enable custom domain support (EFS vs S3)"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "sns_alarm_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms (optional)"
  type        = string
  default     = null
}

# Tagging
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "transfer-family-custom-idp"
    Example     = "enterprise"
    ManagedBy   = "terraform"
    Compliance  = "SOC2"
  }
}
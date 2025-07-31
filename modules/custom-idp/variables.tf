# Required variables
variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.name_prefix))
    error_message = "Name prefix must start with a letter and contain only alphanumeric characters and hyphens."
  }
}

# VPC Configuration
variable "vpc_id" {
  description = "VPC ID where Lambda function will be deployed. Required for VPC-attached Lambda."
  type        = string
  default     = null
  validation {
    condition     = var.vpc_id == null || can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier (vpc-xxxxxxxx)."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda function. Required for VPC-attached Lambda."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for subnet_id in var.subnet_ids : can(regex("^subnet-[0-9a-f]{8,17}$", subnet_id))
    ])
    error_message = "All subnet IDs must be valid subnet identifiers (subnet-xxxxxxxx)."
  }
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda function. Required for VPC-attached Lambda."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for sg_id in var.security_group_ids : can(regex("^sg-[0-9a-f]{8,17}$", sg_id))
    ])
    error_message = "All security group IDs must be valid security group identifiers (sg-xxxxxxxx)."
  }
}

variable "use_vpc" {
  description = "Whether to attach Lambda function to VPC"
  type        = bool
  default     = true
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 45
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 1024
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

# Optional Features
variable "enable_api_gateway" {
  description = "Whether to create API Gateway for REST-based integration"
  type        = bool
  default     = false
}

variable "enable_secrets_manager_permissions" {
  description = "Whether to grant Secrets Manager permissions to Lambda"
  type        = bool
  default     = false
}

variable "enable_xray_tracing" {
  description = "Whether to enable X-Ray tracing"
  type        = bool
  default     = false
}

# DynamoDB Configuration
variable "existing_users_table_name" {
  description = "Name of existing DynamoDB users table. If null, a new table will be created."
  type        = string
  default     = null
}

variable "existing_identity_providers_table_name" {
  description = "Name of existing DynamoDB identity providers table. If null, a new table will be created."
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
variable "kms_key_id" {
  description = "KMS key ID for encryption. If null, AWS managed keys will be used."
  type        = string
  default     = null
}

variable "enable_point_in_time_recovery" {
  description = "Whether to enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = true
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
  default     = 14
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_in_days)
    error_message = "Log retention must be a valid CloudWatch log retention value."
  }
}

# Tagging
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
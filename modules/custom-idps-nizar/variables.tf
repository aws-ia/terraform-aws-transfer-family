variable "stack_name" {
  description = "Name of the stack resources"
  type        = string
  default     = "transfer-idp"
}

variable "aws_region" {
  description = "AWS Region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "use_vpc" {
  description = "Whether to use VPC"
  type        = bool
  default     = true
}

variable "create_vpc" {
  description = "Whether to create a new VPC"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "172.31.0.0/16"
}

variable "vpc_id" {
  description = "Existing VPC ID (leave empty if creating new VPC)"
  type        = string
  default     = ""
}

variable "subnets" {
  description = "Subnet IDs (leave empty if creating new VPC)"
  type        = string
  default     = ""
}

variable "security_groups" {
  description = "Security Group IDs (leave empty if creating new VPC)"
  type        = string
  default     = ""
}

variable "secrets_manager_permissions" {
  description = "Enable Secrets Manager permissions"
  type        = bool
  default     = true
}

variable "user_name_delimiter" {
  description = "Delimiter for usernames"
  type        = string
  default     = "@@"
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "DEBUG"
  
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR."
  }
}

variable "provision_api" {
  description = "Whether to provision API Gateway"
  type        = bool
  default     = true
}

variable "enable_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = true
}

variable "lambda_zip_path" {
  description = "Path to Lambda function ZIP file"
  type        = string
}

variable "users_table_name" {
  description = "DynamoDB users table name (required)"
  type        = string
}

variable "identity_providers_table_name" {
  description = "DynamoDB identity providers table name (required)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

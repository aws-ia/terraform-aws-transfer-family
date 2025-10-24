variable "stack_name" {
  description = "Name of the stack resources"
  type        = string
  default     = "sam-app"
}

variable "lambda_zip_path" {
  description = "Path to Lambda function ZIP file"
  type        = string
}

variable "use_vpc" {
  description = "Whether to use VPC"
  type        = bool
  default     = true
}

variable "create_vpc" {
  description = "Whether to create a new VPC"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "172.31.0.0/16"
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
  default     = ""
}

variable "subnets" {
  description = "Subnet IDs (comma-separated)"
  type        = string
  default     = ""
}

variable "security_groups" {
  description = "Security Group IDs (comma-separated)"
  type        = string
  default     = ""
}

variable "secrets_manager_permissions" {
  description = "Enable Secrets Manager permissions"
  type        = bool
  default     = false
}

variable "user_name_delimiter" {
  description = "Delimiter for usernames"
  type        = string
  default     = "ee"
}

variable "log_level" {
  description = "Log level for Lambda functions"
  type        = string
  default     = "INFO"
}

variable "provision_api" {
  description = "Whether to provision API Gateway"
  type        = bool
  default     = false
}

variable "enable_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
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

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "transfer-idp"
}

variable "github_repository_url" {
  description = "GitHub repository URL for the custom IdP solution"
  type        = string
  default     = "https://github.com/aws-samples/toolkit-for-aws-transfer-family.git"
}

variable "github_branch" {
  description = "Git branch to clone"
  type        = string
  default     = "main"
}

variable "solution_path" {
  description = "Path to solution within repository"
  type        = string
  default     = "solutions/custom-idp"
}

# VPC Configuration
variable "use_vpc" {
  description = "Attach Lambda function to VPC"
  type        = bool
  default     = true
}

variable "create_vpc" {
  description = "Create a new VPC for the solution"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (if creating new VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_id" {
  description = "Existing VPC ID (if not creating new VPC)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "List of subnet IDs for Lambda (if not creating VPC)"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "List of security group IDs for Lambda (if not creating VPC)"
  type        = list(string)
  default     = []
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 1024
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.11"
}

variable "log_level" {
  description = "Log level for Lambda function (INFO or DEBUG)"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["INFO", "DEBUG"], var.log_level)
    error_message = "log_level must be either INFO or DEBUG"
  }
}

variable "username_delimiter" {
  description = "Delimiter for username and IdP name"
  type        = string
  default     = "@@"
}

# DynamoDB Configuration
variable "users_table_name" {
  description = "Name of existing users table. If not provided, a new table will be created"
  type        = string
  default     = ""
}

variable "identity_providers_table_name" {
  description = "Name of existing identity providers table. If not provided, a new table will be created"
  type        = string
  default     = ""
}

# API Gateway Configuration
variable "provision_api" {
  description = "Create API Gateway REST API"
  type        = bool
  default     = false
}

# Secrets Manager
variable "secrets_manager_permissions" {
  description = "Grant Lambda access to Secrets Manager"
  type        = bool
  default     = true
}

# X-Ray Tracing
variable "enable_tracing" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

# CodeBuild Configuration
variable "codebuild_image" {
  description = "CodeBuild Docker image"
  type        = string
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}

variable "codebuild_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "force_build" {
  description = "Force rebuild even if artifacts exist"
  type        = bool
  default     = false
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

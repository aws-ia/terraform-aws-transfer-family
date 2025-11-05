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

# variable "lambda_zip_path" {
#   description = "Path to Lambda function ZIP file"
#   type        = string
# }

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

# GitHub Repository Configuratio
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

# CodeBuild Configuration and environment variables
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

variable "function_artifact_key"{
  description =  "S3 key for the Lambda function deployment package"
  type = string
  default =  "lambda-function.zip"
}

variable "layer_artifact_key"{
  description =  "S3 key for the Lambda layer deployment package"
  type = string
  default =  "lambda-layer.zip"
}

variable "lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.11"
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
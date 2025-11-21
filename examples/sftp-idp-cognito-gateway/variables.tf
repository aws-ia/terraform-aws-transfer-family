variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "sftp-cognito-gateway"
}

variable "cognito_user_pool_name" {
  description = "Name for the Cognito User Pool"
  type        = string
  default     = "sftp-users"
}

variable "cognito_user_pool_client" {
  description = "Name for the Cognito User Pool Client"
  type        = string
  default     = "sftp-client"
}

variable "bucket_prefix" {
  description = "Prefix for S3 bucket name"
  type        = string
  default     = "example"
}

variable "cognito_username" {
  description = "Username for the Cognito user"
  type        = string
  default     = "user1"
}

variable "cognito_user_email" {
  description = "Email address for the Cognito user"
  type        = string
  default     = "user1@example.com"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "sftp-idp-cognito-gateway"
  }
}
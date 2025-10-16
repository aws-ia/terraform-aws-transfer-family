variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "transfer-cognito"
}

variable "server_name" {
  description = "Name of the Transfer Family server"
  type        = string
  default     = "cognito-sftp-server"
}

variable "cognito_user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
  default     = "sftp-users"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Transfer Family configuration"
  type        = string
  default     = "transfer-family-config"
}

variable "bucket_prefix" {
  description = "Prefix for the S3 bucket name"
  type        = string
  default     = "transfer-sftp"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "transfer-cognito"
  }
}

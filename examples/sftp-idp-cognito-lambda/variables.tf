variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "sftp-cognito-example"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "transfer-family-cognito"
  }
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

variable "existing_cognito_user_pool_id" {
  description = "ID of existing Cognito User Pool to use (if not provided, a new pool will be created)"
  type        = string
  default     = null
}

variable "existing_cognito_user_pool_client_id" {
  description = "ID of existing Cognito User Pool Client to use (required if existing_cognito_user_pool_id is provided)"
  type        = string
  default     = null
}

variable "existing_cognito_user_pool_region" {
  description = "Region of existing Cognito User Pool (required if existing_cognito_user_pool_id is provided)"
  type        = string
  default     = null

  validation {
    condition = (
      var.existing_cognito_user_pool_id == null ||
      (var.existing_cognito_user_pool_client_id != null &&
       var.existing_cognito_user_pool_region != null)
    )
    error_message = "When using an existing Cognito User Pool, you must provide existing_cognito_user_pool_client_id and existing_cognito_user_pool_region."
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for DynamoDB tables"
  type        = bool
  default     = true
}

variable "provision_api" {
  description = "Create API Gateway REST API"
  type        = bool
  default     = true
}

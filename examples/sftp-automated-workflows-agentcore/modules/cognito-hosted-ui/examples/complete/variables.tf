variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
  default     = "example-user-pool"
}

variable "domain_prefix" {
  description = "Domain prefix for Cognito hosted UI (must be globally unique)"
  type        = string
}

variable "app_client_name" {
  description = "Name of the Cognito app client"
  type        = string
  default     = "example-app-client"
}

variable "branding_settings" {
  description = "Path to the cognito-branding.json file for Managed Login branding"
  type        = string
  default     = null
}

variable "landing_page_template" {
  description = "Path to the landing page HTML template file"
  type        = string
  default     = null
}

variable "create_landing_page" {
  description = "Whether to create the landing page with CloudFront distribution"
  type        = bool
  default     = true
}

variable "password_policy" {
  description = "Password policy configuration"
  type = object({
    minimum_length                   = number
    require_lowercase                = bool
    require_numbers                  = bool
    require_symbols                  = bool
    require_uppercase                = bool
    temporary_password_validity_days = number
  })
  default = {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }
}

variable "create_test_user" {
  description = "Whether to create a test user"
  type        = bool
  default     = false
}

variable "test_username" {
  description = "Username for the test user"
  type        = string
  default     = "testuser"
}

variable "test_user_email" {
  description = "Email address for the test user"
  type        = string
  default     = "test@example.com"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "example"
    ManagedBy   = "Terraform"
  }
}

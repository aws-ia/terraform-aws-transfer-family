variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format: us-east-1, eu-west-1, etc."
  }
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "transfer-okta"
}

variable "okta_domain" {
  description = "Okta domain (e.g., integrator-7292670.okta.com)"
  type        = string
  default     = "integrator-7292670.okta.com"

  validation {
    condition     = can(regex("^[a-z0-9-]+\\.okta(preview)?\\.com$", var.okta_domain))
    error_message = "Okta domain must be in the format: your-org.okta.com or your-org.oktapreview.com"
  }
}

variable "okta_app_client_id" {
  description = "Okta application client ID for SFTP authentication"
  type        = string
  default     = ""
}

variable "okta_user_email" {
  description = "Email address of the Okta user for SFTP access"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.okta_user_email))
    error_message = "okta_user_email must be a valid email address."
  }
}

variable "okta_mfa_required" {
  description = "Whether MFA is required for Okta authentication. When enabled, users append their TOTP code to their password (e.g., password123456)"
  type        = bool
  default     = false
}

variable "okta_mfa_token_length" {
  description = "The number of digits in the MFA token (default is 6 for most authenticator apps)"
  type        = number
  default     = 6
}

variable "provision_api" {
  description = "Whether to provision API Gateway instead of Lambda for identity provider"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for DynamoDB tables"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Demo"
    Project     = "Transfer-Okta-IDP"
  }
}

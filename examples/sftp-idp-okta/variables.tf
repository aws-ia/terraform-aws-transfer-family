variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "transfer-okta"
}

variable "okta_org_name" {
  description = "Okta organization name (e.g., integrator-7292670)"
  type        = string
  default     = "integrator-7292670"
}

variable "okta_base_url" {
  description = "Okta base URL (okta.com or oktapreview.com)"
  type        = string
  default     = "okta.com"
}

# Authentication Method 1: API Token (Legacy - simpler but less secure)
variable "okta_api_token" {
  description = "Okta API token for Terraform provider authentication (optional if using OAuth2)"
  type        = string
  sensitive   = true
  default     = null
}

# Authentication Method 2: OAuth2 (Recommended - more secure)
variable "okta_client_id" {
  description = "Okta OAuth2 client ID for Terraform provider authentication (optional if using API token)"
  type        = string
  default     = null
}

variable "okta_private_key" {
  description = "Okta OAuth2 private key (PEM format) for Terraform provider authentication (optional if using API token)"
  type        = string
  sensitive   = true
  default     = null
}

variable "okta_private_key_id" {
  description = "Okta OAuth2 private key ID for Terraform provider authentication (optional if using API token)"
  type        = string
  sensitive   = true
  default     = null
}

variable "okta_scopes" {
  description = "Okta OAuth2 scopes for Terraform provider authentication"
  type        = set(string)
  default     = ["okta.users.read", "okta.apps.read", "okta.groups.read"]
}

variable "okta_domain" {
  description = "Okta domain (e.g., integrator-7292670.okta.com)"
  type        = string
  default     = "integrator-7292670.okta.com"
}

variable "okta_app_client_id" {
  description = "Okta application client ID (required only if retrieving user attributes from Okta profiles)"
  type        = string
  default     = "0oax6hum50n7CJNA8697"
}

variable "okta_user_id" {
  description = "Okta user ID (existing user in Okta)"
  type        = string
}

variable "okta_app_id" {
  description = "Okta application ID to assign the user to (optional)"
  type        = string
  default     = ""
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

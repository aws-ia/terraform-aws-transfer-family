variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "sftp-okta-example"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "transfer-family-okta"
  }
}

variable "okta_org_name" {
  description = "Okta organization name (e.g., 'integrator-7292670')"
  type        = string
}

variable "okta_base_url" {
  description = "Okta base URL (e.g., 'okta.com' or 'oktapreview.com')"
  type        = string
  default     = "okta.com"
}

variable "okta_api_token" {
  description = "Okta API token for Terraform provider authentication"
  type        = string
  sensitive   = true
}

variable "okta_domain" {
  description = "Full Okta domain (e.g., 'integrator-7292670.okta.com')"
  type        = string
}

variable "okta_app_client_id" {
  description = "Okta application client ID (optional, required only if retrieving user profile attributes). The Okta application must be configured with Okta API scope okta.users.read.self"
  type        = string
  default     = ""
}

variable "okta_redirect_uri" {
  description = "Sign-in redirect URI for the Okta application (must match allowed URIs in Okta app config)"
  type        = string
  default     = "awstransfer:/callback"
}

variable "okta_enable_mfa" {
  description = "Enable MFA for Okta authentication (users must append MFA token to password)"
  type        = bool
  default     = false
}

variable "okta_mfa_token_length" {
  description = "Number of digits in the MFA token (default: 6)"
  type        = number
  default     = 6

  validation {
    condition     = var.okta_mfa_token_length > 0
    error_message = "MFA token length must be greater than zero."
  }
}

variable "okta_user_id" {
  description = "ID of existing Okta user to grant SFTP access"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for DynamoDB tables"
  type        = bool
  default     = false
}

variable "provision_api" {
  description = "Create API Gateway REST API"
  type        = bool
  default     = false
}

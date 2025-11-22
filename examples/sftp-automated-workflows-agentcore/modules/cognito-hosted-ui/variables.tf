variable "user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
}

variable "domain_prefix" {
  description = "Domain prefix for Cognito hosted UI (must be globally unique)"
  type        = string
}

variable "app_client_name" {
  description = "Name of the Cognito app client"
  type        = string
  default     = "app-client"
}

variable "branding_settings" {
  description = "Path to the cognito-branding.json file for Managed Login branding"
  type        = string
  default     = null
}

variable "landing_page_template" {
  description = "Path to the landing page HTML template file. Required if create_landing_page is true"
  type        = string
  default     = null

  validation {
    condition     = var.create_landing_page ? var.landing_page_template != null : true
    error_message = "landing_page_template must be provided when create_landing_page is true."
  }
}

variable "create_landing_page" {
  description = "Whether to create the landing page with CloudFront distribution. If false, you must provide callback_urls and logout_urls"
  type        = bool
  default     = true
}

variable "landing_page_bucket_name" {
  description = "Name for the S3 bucket hosting the landing page. If not provided, uses domain_prefix"
  type        = string
  default     = ""
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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

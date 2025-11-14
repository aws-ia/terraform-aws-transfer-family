# Variables for Transfer Web App Module

variable "iam_role_name" {
  description = "Name for the IAM role used by the Transfer web app"
  type        = string
  default     = "transfer-web-app-role"
}

variable "identity_center_instance_arn" {
  description = "ARN of the Identity Center instance. If not provided, will use the first available instance"
  type        = string
  default     = null
}

variable "provisioned_units" {
  description = "Number of provisioned web app units"
  type        = number
  default     = 1
  
  validation {
    condition     = var.provisioned_units >= 1 && var.provisioned_units <= 10
    error_message = "Provisioned units must be between 1 and 10."
  }
}

variable "logo_file" {
  description = "Path to logo file for web app customization"
  type        = string
  default     = null
}

variable "favicon_file" {
  description = "Path to favicon file for web app customization"
  type        = string
  default     = null
}

variable "custom_title" {
  description = "Custom title for the web app"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

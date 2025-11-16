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

variable "s3_access_grants_instance_id" {
  description = "ID of the S3 Access Grants instance to use. If not provided, will use the first available instance"
  type        = string
  default     = null
}

variable "s3_bucket_names" {
  description = "List of S3 bucket names to configure CORS for"
  type        = list(string)
  default     = []
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = []
}

variable "cors_allowed_methods" {
  description = "List of allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "PUT", "POST", "DELETE", "HEAD"]
}

variable "cors_allowed_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for audit logging of user authentication and data operations"
  type        = bool
  default     = true
}

variable "cloudtrail_s3_bucket_name" {
  description = "S3 bucket name for CloudTrail logs. If not provided, a bucket will be created"
  type        = string
  default     = null
}

variable "cloudtrail_name" {
  description = "Name for the CloudTrail"
  type        = string
  default     = "transfer-web-app-audit-trail"
}

variable "cloudtrail_sns_topic_arn" {
  description = "SNS topic ARN for CloudTrail notifications"
  type        = string
  default     = null
}

variable "cloudtrail_kms_key_id" {
  description = "KMS key ID for CloudTrail log encryption"
  type        = string
  default     = null
}

variable "access_grants_instance_arn" {
  description = "ARN of the S3 Access Grants instance (required if access grants are configured)"
  type        = string
  default     = null
}

variable "identity_center_users" {
  description = "List of users to assign to the web app"
  type = list(object({
    username = string
    access_grants = optional(list(object({
      location_id = string
      path        = string
      permission  = string
    })))
  }))
  default = []

  validation {
    condition = alltrue([
      for user in var.identity_center_users : alltrue([
        for grant in coalesce(user.access_grants, []) : contains(["READ", "WRITE", "READWRITE"], grant.permission)
      ])
    ])
    error_message = "Access grant permission must be READ, WRITE, or READWRITE."
  }
}

variable "identity_center_groups" {
  description = "List of groups to assign to the web app"
  type = list(object({
    group_name = string
    access_grants = optional(list(object({
      location_id = string
      path        = string
      permission  = string
    })))
  }))
  default = []

  validation {
    condition = alltrue([
      for group in var.identity_center_groups : alltrue([
        for grant in coalesce(group.access_grants, []) : contains(["READ", "WRITE", "READWRITE"], grant.permission)
      ])
    ])
    error_message = "Access grant permission must be READ, WRITE, or READWRITE."
  }
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

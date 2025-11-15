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

variable "s3_access_grants_instance_id" {
  description = "ID of the S3 Access Grants instance to use. If null, a new instance will be created"
  type        = string
  default     = null
}

variable "access_grants" {
  description = "Map of access grants to create"
  type = map(object({
    location_scope     = string
    permission         = optional(string, "READ")
    s3_sub_prefix      = optional(string)
    grantee_type       = optional(string, "IAM")
    grantee_identifier = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for grant in var.access_grants : contains(["READ", "WRITE", "READWRITE"], grant.permission)
    ])
    error_message = "Permission must be READ, WRITE, or READWRITE."
  }

  validation {
    condition = alltrue([
      for grant in var.access_grants : contains(["IAM", "DIRECTORY_USER", "DIRECTORY_GROUP"], grant.grantee_type)
    ])
    error_message = "Grantee type must be IAM, DIRECTORY_USER, or DIRECTORY_GROUP."
  }
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket to grant access to via the web app"
  type        = string
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
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

variable "identity_store_groups" {
  description = "Map of Identity Store groups to create"
  type = map(object({
    display_name = string
    description  = optional(string)
  }))
  default = {}
}

variable "identity_store_users" {
  description = "Map of Identity Store users to create"
  type = map(object({
    display_name = string
    user_name    = string
    given_name   = string
    family_name  = string
    email        = string
  }))
  default = {}
}

variable "group_memberships" {
  description = "Map of group memberships (group_key -> list of user_keys)"
  type        = map(list(string))
  default     = {}
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

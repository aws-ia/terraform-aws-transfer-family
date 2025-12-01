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
  description = "ID of the S3 Access Grants instance to use. If not provided, a new instance will be created"
  type        = string
  default     = null
}

variable "s3_access_grants_location_new" {
  description = "S3 location scope for creating a new access grants location. Set to 's3://' (default) to create a location for all buckets, a specific path like 's3://bucket-name' or 's3://bucket-name/prefix' for a specific location, or null to skip location creation"
  type        = string
  default     = "s3://"
}

variable "s3_access_grants_location_existing" {
  description = "ID of an existing S3 Access Grants location to use. If provided, no new location will be created and s3_access_grants_instance_id must be specified"
  type        = string
  default     = null
}

variable "identity_center_users" {
  description = "List of users to assign to the web app"
  type = list(object({
    username = string
    access_grants = optional(list(object({
      s3_path    = string
      permission = string
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
      s3_path    = string
      permission = string
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

variable "web_app_arn" {
  description = "ARN of the Transfer Family Web App"
  type        = string
}

# Note: identity_store_id is automatically derived from Identity Center
# No need to specify it manually

variable "access_grants_instance_arn" {
  description = "ARN of the S3 Access Grants instance (required if access grants are configured)"
  type        = string
  default     = null
}

variable "users" {
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
      for user in var.users : alltrue([
        for grant in coalesce(user.access_grants, []) : contains(["READ", "WRITE", "READWRITE"], grant.permission)
      ])
    ])
    error_message = "Access grant permission must be READ, WRITE, or READWRITE."
  }
}

variable "groups" {
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
      for group in var.groups : alltrue([
        for grant in coalesce(group.access_grants, []) : contains(["READ", "WRITE", "READWRITE"], grant.permission)
      ])
    ])
    error_message = "Access grant permission must be READ, WRITE, or READWRITE."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

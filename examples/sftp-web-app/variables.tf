variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "identity_center_instance_arn" {
  description = "ARN of the Identity Center instance. If not provided, will use the first available instance"
  type        = string
  default     = null
}

variable "users" {
  description = "Map of users to create with their email addresses"
  type = map(object({
    display_name = string
    given_name   = string
    family_name  = string
    email        = string
  }))
  default = {
    "admin" = {
      display_name = "Admin User"
      given_name   = "Admin"
      family_name  = "User"
      email        = "admin@example.com"
    }
    "analyst" = {
      display_name = "Analyst User"
      given_name   = "Analyst"
      family_name  = "User"
      email        = "analyst@example.com"
    }
  }
}

variable "groups" {
  description = "Map of groups to create"
  type = map(object({
    display_name = string
    description  = string
  }))
  default = {
    "admins" = {
      display_name = "Administrators"
      description  = "Full access to all files and administrative functions"
    }
    "analysts" = {
      display_name = "Analysts"
      description  = "Read access to shared files and write access to analysis folders"
    }
  }
}

variable "group_memberships" {
  description = "Map of group memberships (group_key -> list of user_keys)"
  type        = map(list(string))
  default = {
    "admins"   = ["admin"]
    "analysts" = ["analyst"]
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
  default     = "Company File Portal"
}

variable "access_grant_permissions" {
  description = "Map of group names to their S3 permissions"
  type        = map(string)
  default = {
    "admins"   = "READWRITE"
    "analysts" = "READ"
  }

  validation {
    condition = alltrue([
      for permission in values(var.access_grant_permissions) : contains(["READ", "WRITE", "READWRITE"], permission)
    ])
    error_message = "Permissions must be READ, WRITE, or READWRITE."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Demo"
    Project     = "Web App File Transfer Portal"
  }
}

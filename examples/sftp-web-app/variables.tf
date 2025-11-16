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

variable "access_grants_instance_arn" {
  description = "ARN of the S3 Access Grants instance. If not provided, a new instance will be created"
  type        = string
  default     = null
}

variable "users" {
  description = "Map of users to create"
  type = map(object({
    display_name = string
    user_name    = string
    given_name   = string
    family_name  = string
    email        = string
    access_path  = optional(string)
    permission   = optional(string)
  }))
  default = {
    "admin" = {
      display_name = "Admin User"
      user_name    = "admin"
      given_name   = "Admin"
      family_name  = "User"
      email        = "admin@example.com"
      access_path  = "*"
      permission   = "READWRITE"
    }
    "analyst" = {
      display_name = "Analyst User"
      user_name    = "analyst"
      given_name   = "Analyst"
      family_name  = "User"
      email        = "analyst@example.com"
      # No access_path/permission - inherits from group
    }
  }
}

variable "groups" {
  description = "Map of groups to create"
  type = map(object({
    group_name  = string
    description = string
    members     = optional(list(string))
    access_path = optional(string)
    permission  = optional(string)
  }))
  default = {
    "analysts" = {
      group_name  = "Analysts"
      description = "Read access to files"
      members     = ["analyst"]
      access_path = "*"
      permission  = "READ"
    }
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Demo"
    Project     = "Web App File Transfer Portal"
  }
}

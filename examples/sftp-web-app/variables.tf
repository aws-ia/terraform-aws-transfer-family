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

variable "s3_access_grants_instance_id" {
  description = "ID of the S3 Access Grants instance. If not provided, a new instance will be created"
  type        = string
  default     = null
}

variable "users" {
  description = "Map of users to create"
  type = map(object({
    display_name = string
    user_name    = string
    first_name   = string
    last_name    = string
    email        = string
    access_grants = optional(list(object({
      s3_path    = string
      permission = string
    })))
  }))
  default = {
    "admin" = {
      display_name = "Admin User"
      user_name    = "admin"
      first_name   = "Admin"
      last_name    = "User"
      email        = "admin@example.com"
    }
    "analyst" = {
      display_name = "Analyst User"
      user_name    = "analyst"
      first_name   = "Analyst"
      last_name    = "User"
      email        = "analyst@example.com"
    }
  }

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
  description = "Map of groups to create"
  type = map(object({
    group_name  = string
    description = string
    members     = optional(list(string))
    access_grants = optional(list(object({
      s3_path    = string
      permission = string
    })))
  }))
  default = {
    "admins" = {
      group_name  = "Admins"
      description = "Read and write access to files"
      members     = ["admin"]
      access_grants = [{
        s3_path    = "/*" # Will be prefixed with the newly created bucket name
        permission = "READWRITE"
      }]
    }
    "analysts" = {
      group_name  = "Analysts"
      description = "Read access to files"
      members     = ["analyst"]
      access_grants = [{
        s3_path    = "/*" # Will be prefixed with the newly created bucket name
        permission = "READ"
      }]
    }
  }

  validation {
    condition = alltrue([
      for group in var.groups : alltrue([
        for grant in coalesce(group.access_grants, []) : contains(["READ", "WRITE", "READWRITE"], grant.permission)
      ])
    ])
    error_message = "Access grant permission must be READ, WRITE, or READWRITE."
  }
}

variable "logo_file" {
  description = "Path to logo file for web app customization"
  type        = string
  default     = "anycompany-logo-small.png"
}

variable "favicon_file" {
  description = "Path to favicon file for web app customization"
  type        = string
  default     = "favicon.png"
}

variable "custom_title" {
  description = "Custom title for the web app"
  type        = string
  default     = "AnyCompany Financial Solutions"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Demo"
    Project     = "Web App File Transfer Portal"
  }
}

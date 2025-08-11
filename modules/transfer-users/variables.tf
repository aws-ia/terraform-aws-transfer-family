variable "create_test_user" {
  description = "Whether to create a test SFTP user"
  type        = bool
  default     = false
}

variable "users" {
  description = "List of SFTP users. Each user can have either a single public_key or multiple public_keys, but not both."
  type = list(object({
    username    = string
    home_dir    = string
    public_key  = optional(string)
    public_keys = optional(list(string))
    role_arn    = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for user in var.users :
      !(user.public_key != null && user.public_keys != null)
    ])
    error_message = "Cannot specify both 'public_key' and 'public_keys' for the same user. Use either single 'public_key' or multiple 'public_keys'."
  }

  validation {
    condition = alltrue([
      for user in var.users :
      try(length(user.public_keys), 0) <= 10
    ])
    error_message = "Maximum of 10 public keys allowed per user as per AWS Transfer Family limits."
  }

  validation {
    condition = alltrue([
      for user in var.users :
      user.public_keys == null || try(length(user.public_keys) == length(distinct(user.public_keys)), true)
    ])
    error_message = "Duplicate public keys are not allowed for the same user."
  }

  validation {
    condition = alltrue(flatten([
      for user in var.users : [
        for key in (user.public_keys != null ? user.public_keys : 
                    user.public_key != null ? [user.public_key] : []) :
        can(regex("^(ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-ed25519) AAAA[A-Za-z0-9+/]+[=]{0,3}( .+)?$", key))
      ]
    ]))
    error_message = "All public keys must be in the format '<key-type> <base64-encoded-key> [comment]' where key-type is one of: ssh-rsa (including rsa-sha2-256 and rsa-sha2-512), ecdsa-sha2-nistp256, ecdsa-sha2-nistp384, ecdsa-sha2-nistp521, or ssh-ed25519. The comment is optional."
  }

  validation {
    condition = alltrue([
      for user in var.users :
      user.role_arn == null ||
      user.role_arn == "" ||
      can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", user.role_arn))
    ])
    error_message = "If provided, role_arn must be a valid AWS IAM role ARN in the format: arn:aws:iam::123456789012:role/role-name"
  }
}

variable "server_id" {
  description = "ID of the Transfer Family server"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for SFTP storage"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for SFTP storage"
  type        = string
}

variable "kms_key_id" {
  description = "encryption key"
  type        = string
  default     = null
}
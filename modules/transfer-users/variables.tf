variable "users" {
  description = "List of SFTP users"
  type = list(object({
    username = string
    home_dir = string
    role_arn  = optional(string)
  }))

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

variable "sse_encryption_arn" {
  description = "ARN of the SSE encryption key for S3 bucket"
  type        = string
}

variable "create_ssh_keys" {
  description = "Whether to create new ssh keys for the SFTP Users"
  type        = bool
  default     = true
}

variable "ssh_keys" {
  description = "Map of username to SSH public key content"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k, v in var.ssh_keys : can(regex("^ssh-rsa AAAA[0-9A-Za-z+/]+[=]{0,3}( [^@]+@[^@]+)?$", v))])
    error_message = "All SSH keys must be valid RSA public keys in the format 'ssh-rsa AAAA...'."
  }
}
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format: us-east-1, eu-west-1, etc."
  }
}

variable "existing_secret_arn" {
  description = "ARN of an existing Secrets Manager secret containing SFTP credentials (must contain username and either password or privateKey). If not provided, a new secret will be created."
  type        = string
  default     = ""

  validation {
    condition     = var.existing_secret_arn == "" || can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", var.existing_secret_arn))
    error_message = "If provided, existing_secret_arn must be a valid AWS Secrets Manager ARN in the format: arn:aws:secretsmanager:region:123456789012:secret:secret-name"
  }
}

variable "sftp_username" {
  description = "Username for SFTP authentication (used only if existing_secret_arn is not provided)"
  type        = string
  default     = "sftp-user"

  validation {
    condition     = length(var.sftp_username) > 0 && length(var.sftp_username) <= 100
    error_message = "SFTP username must be between 1 and 100 characters long."
  }
}

variable "sftp_password" {
  description = "Password for SFTP authentication (used only if existing_secret_arn is not provided)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sftp_private_key" {
  description = "Private key for SFTP authentication (used only if existing_secret_arn is not provided)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "trust_all_certificates" {
  description = "Whether to trust all certificates for the SFTP connection"
  type        = bool
  default     = false
}

variable "sftp_remote_path" {
  description = "Remote path on the SFTP server where files will be uploaded (e.g., /upload)"
  type        = string
  default     = "/"

  validation {
    condition     = can(regex("^/.*$", var.sftp_remote_path))
    error_message = "SFTP remote path must start with a forward slash (/)."
  }
}

variable "trusted_host_keys" {
  description = "List of trusted host keys for the SFTP server (required for secure connections)"
  type        = list(string)
  default     = []
}

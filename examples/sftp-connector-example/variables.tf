variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "existing_secret_arn" {
  description = "ARN of an existing Secrets Manager secret containing SFTP credentials (must contain username and either password or privateKey). If not provided, a new secret will be created."
  type        = string
  default     = ""  # Make it optional
}

variable "sftp_username" {
  description = "Username for SFTP authentication (used only if existing_secret_arn is not provided)"
  type        = string
  default     = "sftp-user"
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
}

variable "trusted_host_keys" {
  description = "List of trusted host keys for the SFTP server (required for secure connections)"
  type        = list(string)
  default     = []
}

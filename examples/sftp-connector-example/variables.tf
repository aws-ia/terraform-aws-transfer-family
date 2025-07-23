variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "sftp_username" {
  description = "Username for SFTP authentication"
  type        = string
}

variable "sftp_password" {
  description = "Password for SFTP authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sftp_private_key" {
  description = "Private key for SFTP authentication"
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

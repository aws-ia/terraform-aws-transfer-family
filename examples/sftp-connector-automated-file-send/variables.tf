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
  default     = null

  validation {
    condition     = var.existing_secret_arn == null || var.existing_secret_arn == "" || can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", var.existing_secret_arn))
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
  description = "Password for SFTP authentication (used only if existing_secret_arn is not provided and sftp_private_key is not provided)"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.existing_secret_arn != null || var.sftp_password != "" || var.sftp_private_key != ""
    error_message = "Either existing_secret_arn must be provided, or sftp_password or sftp_private_key must be provided."
  }
}

variable "sftp_private_key" {
  description = "Private key for SFTP authentication (used only if existing_secret_arn is not provided and sftp_password is not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "trusted_host_keys" {
  description = "List of trusted host keys for the SFTP server (required for secure connections)"
  type        = list(string)
  default     = []
}

variable "sftp_server_endpoint" {
  description = "SFTP server endpoint hostname (e.g., s-1234567890abcdef0.server.transfer.us-east-1.amazonaws.com or example.com) - sftp:// prefix will be added automatically"
  type        = string
}

variable "source_s3_bucket_name" {
  description = "S3 bucket name for AWS Transfer Family server (if connecting to AWS SFTP)"
  type        = string
  default     = null
}

variable "source_s3_bucket_arn" {
  description = "S3 bucket ARN for AWS Transfer Family server (if connecting to AWS SFTP)"
  type        = string
  default     = null
}

variable "test_connector_post_deployment" {
  description = "Whether to test the connector connection after deployment"
  type        = bool
  default     = false
}

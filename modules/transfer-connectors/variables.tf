#####################################################################################
# Variables for AWS Transfer Family SFTP Connector Module
#####################################################################################

variable "transfer_server_id" {
  description = "ID of the AWS Transfer Family server (used for dependency management)"
  type        = string
  default     = null
}

variable "connector_name" {
  description = "Name of the AWS Transfer Family connector"
  type        = string
  default     = "sftp-connector"
}

variable "sftp_server_url" {
  description = "URL of the SFTP server to connect to (e.g., sftp://example.com:22 or sftp://example.com)"
  type        = string

  validation {
    condition     = can(regex("^sftp://[a-zA-Z0-9.-]+(:[0-9]+)?$", var.sftp_server_url))
    error_message = "SFTP server URL must be in format 'sftp://hostname' or 'sftp://hostname:port'."
  }
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket to connect to the SFTP server"
  type        = string
}

variable "s3_access_role_arn" {
  description = "ARN of the IAM role for S3 access (if not provided, a new role will be created)"
  type        = string
  default     = null
}

variable "logging_role_arn" {
  description = "ARN of the IAM role for CloudWatch logging (if not provided, a new role will be created)"
  type        = string
  default     = null
}

variable "sftp_username" {
  description = "Username for SFTP authentication"
  type        = string
}

variable "sftp_password" {
  description = "Password for SFTP authentication (use either password or private_key, not both)"
  type        = string
  sensitive   = true
  default     = null
}

variable "sftp_private_key" {
  description = "SSH private key for SFTP authentication (use either password or private_key, not both)"
  type        = string
  sensitive   = true
  default     = null
}

variable "trusted_host_keys" {
  description = "List of trusted host keys for the SFTP server. Leave empty to auto-discover."
  type        = list(string)
  default     = []
}

variable "auto_discover_host_keys" {
  description = "Whether to auto-discover trusted host keys from the SFTP server"
  type        = bool
  default     = true
}

variable "max_concurrent_connections" {
  description = "Maximum number of concurrent connections to the SFTP server"
  type        = number
  default     = 1

  validation {
    condition     = var.max_concurrent_connections >= 1 && var.max_concurrent_connections <= 10
    error_message = "Max concurrent connections must be between 1 and 10."
  }
}

variable "security_policy_name" {
  description = "The name of the security policy to use for the connector"
  type        = string
  default     = "TransferSFTPConnectorSecurityPolicy-2024-03"

  validation {
    condition = contains([
      "TransferSecurityPolicy-2018-11",
      "TransferSecurityPolicy-2020-06",
      "TransferSecurityPolicy-2022-03",
      "TransferSecurityPolicy-2023-05",
      "TransferSecurityPolicy-2024-01",
      "TransferSecurityPolicy-FIPS-2020-06",
      "TransferSecurityPolicy-FIPS-2023-05",
      "TransferSecurityPolicy-FIPS-2024-01",
      "TransferSecurityPolicy-PQ-SSH-Experimental-2023-04",
      "TransferSecurityPolicy-PQ-SSH-FIPS-Experimental-2023-04"
    ], var.security_policy_name) || can(regex("^TransferSFTPConnectorSecurityPolicy-[A-Za-z0-9-]+$", var.security_policy_name))
    error_message = "Security policy name must be a valid AWS Transfer Family security policy or SFTP connector security policy (TransferSFTPConnectorSecurityPolicy-*)."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encrypting secrets"
  type        = string
  default     = null
}

variable "enable_kms_encryption" {
  description = "Whether to enable KMS encryption for secrets"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}
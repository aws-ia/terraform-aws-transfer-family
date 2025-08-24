#####################################################################################
# Variables for AWS Transfer Family SFTP Connector Module
#####################################################################################

variable "connector_name" {
  description = "Name of the AWS Transfer Family connector"
  type        = string
  default     = "sftp-connector"
}

variable "url" {
  description = "URL of the SFTP server to connect to (e.g., example.com or sftp://example.com:22)"
  type        = string

  validation {
    condition     = can(regex("^(sftp://)?[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$", var.url))
    error_message = "URL must be a valid hostname with optional sftp:// prefix, port, and path."
  }
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket to connect to the SFTP server"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:s3:::[a-z0-9.-]+$", var.s3_bucket_arn))
    error_message = "S3 bucket ARN must be in the format: arn:aws:s3:::bucket-name"
  }
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to connect to the SFTP server"
  type        = string
}

variable "user_secret_id" {
  description = "ARN of the AWS Secrets Manager secret containing SFTP credentials (optional - will auto-detect for AWS Transfer Family servers)"
  type        = string
  default     = null

  validation {
    condition     = var.user_secret_id == null || can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", var.user_secret_id))
    error_message = "user_secret_id must be a valid AWS Secrets Manager ARN in the format: arn:aws:secretsmanager:region:123456789012:secret:secret-name"
  }
}

variable "security_policy_name" {
  description = "The name of the security policy to use for the connector (must be in the format TransferSFTPConnectorSecurityPolicy-*)"
  type        = string
  default     = "TransferSFTPConnectorSecurityPolicy-2024-03"

  validation {
    condition     = can(regex("^TransferSFTPConnectorSecurityPolicy-[0-9]{4}-[0-9]{2}$", var.security_policy_name))
    error_message = "Security policy name must be in the format TransferSFTPConnectorSecurityPolicy-YYYY-MM (e.g., TransferSFTPConnectorSecurityPolicy-2024-03)"
  }
}

variable "logging_role" {
  description = "IAM role ARN for CloudWatch logging (if not provided, a new role will be created)"
  type        = string
  default     = null
}

variable "S3_kms_key_arn" {
  description = "ARN of the KMS key used for encryption (optional)"
  type        = string
  default     = null
}

variable "secrets_manager_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the secrets manager secret containing SFTP credentials"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}

variable "as2_mdn_response" {
  description = "AS2 MDN response for the connector"
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["SYNC", "NONE"], var.as2_mdn_response)
    error_message = "AS2 MDN response must be either 'SYNC' or 'NONE'"
  }
}

variable "as2_signing_algorithm" {
  description = "AS2 signing algorithm for the connector"
  type        = string
  default     = "NONE"
}

variable "as2_mdn_signing_algorithm" {
  description = "AS2 MDN signing algorithm for the connector"
  type        = string
  default     = "NONE"
}

variable "trusted_host_keys" {
  description = "List of trusted host keys for the SFTP server. If empty, SSH key auto-discovery will run automatically."
  type        = list(string)
  default     = []
}
variable "sftp_password" {
  description = "SFTP password for authentication (optional if using private key)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "sftp_private_key" {
  description = "SFTP private key for authentication (optional if using password)"
  type        = string
  default     = ""
  sensitive   = true
}
variable "create_secret" {
  description = "Whether to create a new secret for SFTP credentials"
  type        = bool
  default     = false
}

variable "secret_name" {
  description = "Name for the new secret (only used when create_secret is true)"
  type        = string
  default     = null
}

variable "secret_kms_key_id" {
  description = "KMS key ID for encrypting the secret"
  type        = string
  default     = null
}

variable "sftp_username" {
  description = "SFTP username for authentication"
  type        = string
  default     = ""
}

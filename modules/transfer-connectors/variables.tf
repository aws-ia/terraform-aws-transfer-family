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

variable "test_connector_post_deployment" {
  description = "Whether to test the connector connection after deployment"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}

variable "trusted_host_keys" {
  description = "Trusted-Host-Key is the public portion of the host key(s) that is used to identify the remote server you need to connect to. You can enter the Trusted Host Key(s) now, or add them after creating the connector by using the host key information returned by the TestConnection action. Note that your connector will be able to create connections to the remote server only if the server's SSH fingerprint matches one of the provided Trusted Host Key(s). If empty, SSH key auto-discovery will run automatically."
  type        = list(string)
  default     = []
}

variable "sftp_private_key" {
  description = "SFTP private key for authentication (optional if using password)"
  type        = string
  default     = ""
  sensitive   = true
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

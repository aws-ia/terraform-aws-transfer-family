#####################################################################################
# Variables for AWS Transfer Family SFTP Connector Module
#####################################################################################

variable "connector_name" {
  description = "Name of the AWS Transfer Family connector"
  type        = string
  default     = "sftp-connector"
}

variable "url" {
  description = "URL of the SFTP server to connect to (e.g., sftp://example.com:22)"
  type        = string

  validation {
    condition     = can(regex("^(sftp|http|https)://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$", var.url))
    error_message = "URL must be a valid format starting with sftp://, http://, or https:// followed by a hostname and optional port/path."
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
  description = "ARN of the AWS Secrets Manager secret containing SFTP credentials"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", var.user_secret_id))
    error_message = "user_secret_id must be a valid AWS Secrets Manager ARN in the format: arn:aws:secretsmanager:region:123456789012:secret:secret-name"
  }
}

variable "as2_username" {
  description = "Username for AS2 basic authentication"
  type        = string
  default     = ""
}

variable "as2_password" {
  description = "Password for AS2 basic authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "trust_all_certificates" {
  description = "Whether to trust all certificates for the SFTP connection"
  type        = bool
  default     = false
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

variable "kms_key_arn" {
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

variable "as2_local_profile_id" {
  description = "AS2 local profile ID for the connector (required for AS2 config)"
  type        = string
  default     = ""
}

variable "as2_mdn_response" {
  description = "AS2 MDN response for the connector (required for AS2 config)"
  type        = string
  default     = ""
}

variable "as2_partner_profile_id" {
  description = "AS2 partner profile ID for the connector (required for AS2 config)"
  type        = string
  default     = ""
}

variable "as2_signing_algorithm" {
  description = "AS2 signing algorithm for the connector (required for AS2 config)"
  type        = string
  default     = ""
}
variable "enable_ssh_key_scanning" {
  description = "Whether to automatically scan and retrieve SSH host keys from the remote SFTP server. Auto-discovery also runs automatically when trusted_host_keys is empty."
  type        = bool
  default     = false
}

variable "trusted_host_keys" {
  description = "List of trusted host keys for the SFTP server. If empty, SSH key auto-discovery will run automatically."
  type        = list(string)
  default     = []
}

variable "as2_compression" {
  description = "AS2 compression setting for the connector (required for AS2 config)"
  type        = bool
  default     = false
}

variable "as2_encryption_algorithm" {
  description = "Encryption algorithm for AS2 connector"
  type        = string
  default     = ""
}
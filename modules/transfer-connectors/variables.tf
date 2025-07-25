#####################################################################################
# Variables for AWS Transfer Family SFTP Connector Module
#####################################################################################

variable "connector_name" {
  description = "Name of the AWS Transfer Family connector"
  type        = string
  default     = "sftp-connector"
}

variable "sftp_server_url" {
  description = "URL of the SFTP server to connect to (e.g., sftp://example.com:22)"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket to connect to the SFTP server"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to connect to the SFTP server"
  type        = string
}

variable "user_secret_id" {
  description = "ARN of the AWS Secrets Manager secret containing SFTP credentials"
  type        = string
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
}

variable "logging_role" {
  description = "IAM role ARN for CloudWatch logging (if not provided, a new role will be created)"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
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
variable "trusted_host_keys" {
  description = "List of trusted host keys for the SFTP server"
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
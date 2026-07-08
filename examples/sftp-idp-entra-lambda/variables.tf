variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "sftp-entra-example"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "transfer-family-entra"
  }
}

variable "entra_usernames" {
  description = "Usernames for Entra users"
  type        = list(string)
  default     = ["user1@example.onmicrosoft.com"]

  validation {
    condition     = length(var.entra_usernames) > 0
    error_message = "At least one Entra username must be provided."
  }
}

variable "entra_client_id" {
  description = "Client/Application ID of existing Entra ID enterprise application"
  type        = string
  default     = null

  validation {
    condition     = var.entra_client_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.entra_client_id))
    error_message = "Entra client ID must be a valid UUID format."
  }
}

variable "entra_client_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing the Entra ID client secret"
  type        = string
  default     = null

  validation {
    condition     = var.entra_client_secret_arn == null || can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:\\d{12}:secret:.+$", var.entra_client_secret_arn))
    error_message = "Entra client secret ARN must be a valid AWS Secrets Manager secret ARN."
  }
}

variable "entra_authority_url" {
  description = "Authority URL of existing Entra ID enterprise application"
  type        = string
  default     = null

  validation {
    condition     = var.entra_authority_url == null || can(regex("^https://", var.entra_authority_url))
    error_message = "Entra authority URL must start with https://."
  }
}

variable "entra_provider_name" {
  description = "Provider name of existing Entra ID enterprise application"
  type        = string
  default     = null

  validation {
    condition     = var.entra_provider_name == null || length(var.entra_provider_name) > 0
    error_message = "Entra provider name cannot be empty if provided."
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for DynamoDB tables"
  type        = bool
  default     = true
}

variable "provision_api" {
  description = "Create API Gateway REST API"
  type        = bool
  default     = false
}

variable "users_table_name" {
  description = "Name of an existing DynamoDB table for users. If not provided, a new table will be created."
  type        = string
  default     = ""
}

variable "identity_providers_table_name" {
  description = "Name of an existing DynamoDB table for identity providers. If not provided, a new table will be created."
  type        = string
  default     = ""
}

variable "default_user_ipv4_allow_list" {
  description = "List of IPv4 CIDR blocks allowed to connect as the default user. Restrict to specific IPs in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.default_user_ipv4_allow_list) > 0
    error_message = "At least one CIDR block must be provided."
  }
}

variable "s3_sse_algorithm" {
  description = "Server-side encryption algorithm for the S3 bucket. Use 'AES256' for S3-managed keys or 'aws:kms' for KMS-managed keys."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.s3_sse_algorithm)
    error_message = "SSE algorithm must be either 'AES256' or 'aws:kms'."
  }
}

variable "s3_kms_key_id" {
  description = "ARN of the KMS key to use for S3 bucket encryption. Only used when s3_sse_algorithm is 'aws:kms'. If not provided, the AWS managed KMS key is used."
  type        = string
  default     = null
}

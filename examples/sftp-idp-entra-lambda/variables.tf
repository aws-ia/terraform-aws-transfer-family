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
  description = "Username for the Entra user"
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

variable "entra_client_secret_name" {
  description = "Name of the AWS Secrets Manager secret containing the Entra ID client secret"
  type        = string
  default     = null

  validation {
    condition     = var.entra_client_secret_name == null || length(var.entra_client_secret_name) > 0
    error_message = "Entra client secret name cannot be empty if provided."
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
  default     = false
}

variable "provision_api" {
  description = "Create API Gateway REST API"
  type        = bool
  default     = false
}

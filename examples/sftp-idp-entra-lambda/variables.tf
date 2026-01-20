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
}

variable "entra_client_id" {
  description = "Client/Application ID of existing Entra ID enterprise application"
  type        = string
  default     = null
}

variable "entra_client_secret" {
  description = "Client secret of existing Entra ID enterprise application"
  type        = string
  default     = null
  sensitive   = true
}

variable "entra_authority_url" {
  description = "Authority URL of existing Entra ID enterprise application"
  type        = string
  default     = null
}

variable "entra_provider_name" {
  description = "Provider name of existing Entra ID enterprise application"
  type        = string
  default     = null
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for DynamoDB tables"
  type        = bool
  default     = true
}


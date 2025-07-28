#####################################################################################
# Variables for SFTP Connector Example with Automated File Send Workflow
#####################################################################################

# Transfer Family Server Configuration
variable "dns_provider" {
  type        = string
  description = "The DNS provider for the custom hostname. Use null for no custom hostname"
  default     = null
}

variable "custom_hostname" {
  type        = string
  description = "The custom hostname for the Transfer Family server"
  default     = null
}

variable "route53_hosted_zone_name" {
  description = "The name of the Route53 hosted zone to use (must end with a period, e.g., 'example.com.')"
  type        = string
  default     = null
}

variable "logging_role" {
  description = "IAM role ARN that the Transfer Server assumes to write logs to CloudWatch Logs"
  type        = string
  default     = null
}

variable "workflow_details" {
  description = "Workflow details to attach to the transfer server"
  type = object({
    on_upload = optional(object({
      execution_role = string
      workflow_id    = string
    }))
    on_partial_upload = optional(object({
      execution_role = string
      workflow_id    = string
    }))
  })
  default = null
}

variable "users_file" {
  description = "Path to CSV file containing user configurations for the Transfer Family server"
  type        = string
  default     = null
}

# SFTP Connector Configuration
variable "sftp_username" {
  description = "Username for SFTP authentication (should match a user created on the Transfer Family server)"
  type        = string
  default     = "test_user"  # Default test user created by the transfer-users module
}

variable "trusted_host_keys" {
  description = "List of trusted host keys for the SFTP server (leave empty for auto-discovery)"
  type        = list(string)
  default     = []
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
}

variable "existing_s3_role_arn" {
  description = "ARN of existing IAM role for S3 access (optional)"
  type        = string
  default     = null
}

variable "existing_logging_role_arn" {
  description = "ARN of existing IAM role for logging (optional)"
  type        = string
  default     = null
}

# Automated File Send Workflow Configuration
variable "existing_connector_id" {
  description = "ID of existing SFTP connector to use for file sending. If not provided, a new connector will be created."
  type        = string
  default     = null
}

variable "s3_monitoring_prefix" {
  description = "S3 prefix to monitor for new files that should trigger automated file sending"
  type        = string
  default     = "outbound/"
}

variable "remote_directory_path" {
  description = "Remote directory path on the SFTP server where files will be sent"
  type        = string
  default     = "/uploads"
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "sftp-connector-automated-file-send"
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "stage" {
  description = "Environment stage (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

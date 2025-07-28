#####################################################################################
# Variables for SFTP Connector Example with Automated File Retrieve Workflow
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

# Automated File Retrieve Workflow Configuration
variable "existing_connector_id" {
  description = "ID of existing SFTP connector to use for file retrieval. If not provided, a new connector will be created."
  type        = string
  default     = null
}

variable "s3_destination_prefix" {
  description = "S3 prefix where retrieved files will be stored (Local directory path)"
  type        = string
  default     = "retrieved/"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9!_.*'()-/]*/$", var.s3_destination_prefix))
    error_message = "S3 destination prefix must be a valid S3 prefix ending with '/'."
  }
}

variable "eventbridge_schedule_expression" {
  description = "EventBridge schedule expression for automated file retrieval (e.g., 'rate(1 hour)', 'cron(0 9 * * ? *)')"
  type        = string
  default     = "rate(1 hour)"
  
  validation {
    condition = can(regex("^(rate\\([0-9]+ (minute|minutes|hour|hours|day|days)\\)|cron\\(.+\\))$", var.eventbridge_schedule_expression))
    error_message = "EventBridge schedule expression must be a valid rate or cron expression."
  }
}

variable "enable_automated_schedule" {
  description = "Enable the EventBridge schedule for automated file retrieval. Set to false for manual testing only."
  type        = bool
  default     = true
}

variable "sample_file_paths" {
  description = "List of sample file paths to be added to DynamoDB for retrieval"
  type        = list(string)
  default = [
    "/uploads/sample1.txt",
    "/uploads/sample2.txt",
    "/uploads/documents/report.pdf"
  ]
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "sftp-connector-automated-file-retrieve"
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

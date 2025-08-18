variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format: us-east-1, eu-west-1, etc."
  }
}

variable "existing_secret_arn" {
  description = "ARN of an existing Secrets Manager secret containing SFTP credentials (must contain username and either password or privateKey). If not provided, a new secret will be created."
  type        = string
  default     = null

  validation {
    condition     = var.existing_secret_arn == "" || can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", var.existing_secret_arn))
    error_message = "If provided, existing_secret_arn must be a valid AWS Secrets Manager ARN in the format: arn:aws:secretsmanager:region:123456789012:secret:secret-name"
  }
}

variable "sftp_username" {
  description = "Username for SFTP authentication (used only if existing_secret_arn is not provided)"
  type        = string
  default     = "sftp-user"

  validation {
    condition     = length(var.sftp_username) > 0 && length(var.sftp_username) <= 100
    error_message = "SFTP username must be between 1 and 100 characters long."
  }
}

variable "sftp_password" {
  description = "Password for SFTP authentication (used only if existing_secret_arn is not provided and sftp_private_key is not provided)"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.existing_secret_arn != "" || var.sftp_password != "" || var.sftp_private_key != ""
    error_message = "Either existing_secret_arn must be provided, or sftp_password or sftp_private_key must be provided."
  }
}

variable "sftp_private_key" {
  description = "Private key for SFTP authentication (used only if existing_secret_arn is not provided and sftp_password is not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "trusted_host_keys" {
  description = "List of trusted host keys for the SFTP server (required for secure connections)"
  type        = list(string)
  default     = []
}

variable "sftp_server_endpoint" {
  description = "SFTP server endpoint hostname (e.g., example.com) - sftp:// prefix will be added automatically"
  type        = string
}

variable "connector_id" {
  description = "Existing connector ID to use for file retrieval. If not provided, a new connector will be created."
  type        = string
  default     = null
}

variable "s3_prefix" {
  description = "S3 prefix to store retrieved files (local directory path)"
  type        = string
  default     = "retrieved-files"

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_-]+$", var.s3_prefix))
    error_message = "S3 prefix must contain only alphanumeric characters, hyphens, underscores, and forward slashes."
  }
}

variable "eventbridge_schedule" {
  description = "EventBridge schedule expression for automated file retrieval (e.g., 'rate(1 hour)' or 'cron(0 9 * * ? *)')"
  type        = string
  default     = "rate(1 hour)"

  validation {
    condition     = can(regex("^(rate\\([0-9]+ (minute|minutes|hour|hours|day|days)\\)|cron\\(.+\\))$", var.eventbridge_schedule))
    error_message = "EventBridge schedule must be in rate() or cron() format. Examples: 'rate(1 hour)', 'cron(0 9 * * ? *)'."
  }
}

variable "file_paths_to_retrieve" {
  description = "List of file paths on the remote SFTP server to retrieve"
  type        = list(string)
  default     = ["/remote/path/file1.txt", "/remote/path/file2.txt"]

  validation {
    condition     = length(var.file_paths_to_retrieve) > 0
    error_message = "At least one file path must be specified."
  }

  validation {
    condition = alltrue([
      for path in var.file_paths_to_retrieve : can(regex("^/.+", path))
    ])
    error_message = "All file paths must start with a forward slash (/)."
  }
}
variable "workflow_type" {
  description = "Workflow type: 'static' for EventBridge Scheduler with static files, 'directory' for Lambda with directory listing"
  type        = string
  default     = "static"
  
  validation {
    condition     = contains(["static", "directory"], var.workflow_type)
    error_message = "Workflow type must be either 'static' or 'directory'."
  }
}

variable "source_directory" {
  description = "Source directory path on remote server (reserved for future directory workflow)"
  type        = string
  default     = "/uploads"
  
  validation {
    condition     = can(regex("^/.*", var.source_directory))
    error_message = "Source directory must start with a forward slash."
  }
}

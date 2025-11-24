variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "sftp-cognito-example"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "transfer-family-cognito"
  }
}

variable "cognito_username" {
  description = "Username for the Cognito user"
  type        = string
  default     = "user1"
}

variable "cognito_user_email" {
  description = "Email address for the Cognito user"
  type        = string
  default     = "user1@example.com"
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
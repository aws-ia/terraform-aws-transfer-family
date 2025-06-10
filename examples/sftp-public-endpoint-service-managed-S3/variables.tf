variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "users_file" {
  description = "Path to CSV file containing user configurations"
  type        = string
  default     = "users.csv"
}

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
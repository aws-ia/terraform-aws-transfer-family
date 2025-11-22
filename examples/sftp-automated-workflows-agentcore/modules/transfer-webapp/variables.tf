variable "web_app_name" {
  description = "Name of the Transfer Family Web App"
  type        = string
}

variable "identity_center_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  type        = string
}

variable "access_endpoint" {
  description = "Custom endpoint URL for the web app. If null, uses the default AWS-provided endpoint"
  type        = string
  default     = null
}

variable "access_grants_instance_arn" {
  description = "ARN of an existing S3 Access Grants instance"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "web_app_name" {
  description = "Name of the Transfer Family Web App"
  type        = string
  default     = "demo-transfer-webapp"
}

variable "identity_center_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  type        = string
}

# S3 Bucket Configuration
variable "uploads_bucket_name" {
  description = "Name of the S3 bucket for user uploads (will be created)"
  type        = string
  default     = "demo-transfer-uploads"
}

variable "shared_bucket_name" {
  description = "Name of existing S3 bucket for shared documents"
  type        = string
}

# User and Group Configuration
variable "user1_username" {
  description = "Username of the first user (must exist in Identity Center)"
  type        = string
  default     = "claims.reviewer"
}

variable "user2_username" {
  description = "Username of the second user (must exist in Identity Center)"
  type        = string
  default     = "john.doe"
}

variable "group_name" {
  description = "Name of the group (must exist in Identity Center)"
  type        = string
  default     = "Claims Team"
}

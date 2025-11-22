variable "location_name" {
  description = "Name for this location (used in resource naming)"
  type        = string
}

variable "create_bucket" {
  description = "Whether to create a new S3 bucket"
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "Name of existing bucket (if create_bucket is false) or name for new bucket (if create_bucket is true)"
  type        = string
}

variable "bucket_prefix" {
  description = "Prefix for the S3 bucket path (e.g., 'uploads/'). Must end with '/'"
  type        = string
  default     = ""
}

variable "access_grants_instance_arn" {
  description = "ARN of the S3 Access Grants instance"
  type        = string
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS (e.g., web app endpoint). Only applies if create_bucket is true"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

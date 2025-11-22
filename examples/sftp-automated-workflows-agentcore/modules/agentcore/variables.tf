variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "claims-processing"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "log_level" {
  description = "Log level for agents"
  type        = string
  default     = "INFO"
}

variable "bucket_name" {
  description = "S3 bucket name for claims"
  type        = string
}

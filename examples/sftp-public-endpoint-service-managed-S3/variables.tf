variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for SFTP storage"
  type        = string
}

variable "users_file" {
  description = "Path to CSV file containing user configurations"
  type        = string
  default     = "users.csv"
}
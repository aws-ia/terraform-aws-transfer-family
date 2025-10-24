variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "stack_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "sftp-cognito-gateway"
}

variable "test_username" {
  description = "Test username for SFTP access"
  type        = string
  default     = "testuser"
}

variable "test_email" {
  description = "Test user email"
  type        = string
  default     = "test@example.com"
}

variable "test_password" {
  description = "Test user password"
  type        = string
  default     = "TempPass123!"
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "transfer-family-cognito-gateway"
  }
}

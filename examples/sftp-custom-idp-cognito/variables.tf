variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "test_username" {
  description = "Username for the test user (must be email format)"
  type        = string
  default     = "Test"
}

variable "test_user_email" {
  description = "Email address for the test user"
  type        = string
  default     = "test@example.com"
}

variable "test_user_temp_password" {
  description = "Temporary password for the test user (will be changed)"
  type        = string
  default     = "TempPass123!"
  sensitive   = true
}

variable "test_user_password" {
  description = "Permanent password for the test user"
  type        = string
  default     = "TestPass123!"
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "test"
    Project     = "transfer-family-cognito-example"
    ManagedBy   = "terraform"
  }
}
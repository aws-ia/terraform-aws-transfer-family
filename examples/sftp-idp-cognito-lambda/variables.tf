variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "stack_name" {
  description = "Name prefix for all resources"
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
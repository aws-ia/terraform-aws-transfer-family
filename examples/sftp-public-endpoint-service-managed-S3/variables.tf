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
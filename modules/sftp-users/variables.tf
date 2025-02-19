variable "users" {
  description = "List of SFTP users"
  type = list(object({
    username = string
    home_dir = string
  }))
}

variable "server_id" {
  description = "ID of the Transfer Family server"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for SFTP storage"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for SFTP storage"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
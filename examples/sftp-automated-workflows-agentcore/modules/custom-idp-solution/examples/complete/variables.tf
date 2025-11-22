variable "cognito_user_pool_client_id" {
  description = "ID of the existing Cognito User Pool Client"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the existing S3 bucket for Transfer Family access"
  type        = string
}

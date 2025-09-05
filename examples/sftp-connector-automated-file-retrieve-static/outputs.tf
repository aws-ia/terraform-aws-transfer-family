output "connector_id" {
  description = "The ID of the SFTP connector"
  value       = module.sftp_connector.connector_id
}

output "connector_arn" {
  description = "The ARN of the SFTP connector"
  value       = module.sftp_connector.connector_arn
}

output "retrieve_bucket_name" {
  description = "Name of the S3 bucket for retrieved files"
  value       = module.retrieve_s3_bucket.s3_bucket_id
}

output "retrieve_bucket_arn" {
  description = "ARN of the S3 bucket for retrieved files"
  value       = module.retrieve_s3_bucket.s3_bucket_arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = local.kms_key_arn
}

output "eventbridge_schedule_name" {
  description = "Name of the EventBridge schedule"
  value       = aws_scheduler_schedule.sftp_retrieve_direct.name
}

output "eventbridge_schedule_arn" {
  description = "ARN of the EventBridge schedule"
  value       = aws_scheduler_schedule.sftp_retrieve_direct.arn
}

output "sftp_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing SFTP credentials"
  value       = var.existing_secret_arn != null ? var.existing_secret_arn : module.sftp_connector.secret_arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for file transfer tracking (if enabled)"
  value       = var.enable_dynamodb_tracking ? aws_dynamodb_table.file_transfer_tracking[0].name : null
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for file transfer tracking (if enabled)"
  value       = var.enable_dynamodb_tracking ? aws_dynamodb_table.file_transfer_tracking[0].arn : null
}

output "connector_static_ips" {
  description = "Static IP addresses of the SFTP connector"
  value       = module.sftp_connector.connector_static_ips
}


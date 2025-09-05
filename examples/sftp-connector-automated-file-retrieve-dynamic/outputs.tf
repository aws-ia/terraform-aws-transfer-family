output "connector_arn" {
  description = "ARN of the SFTP connector"
  value       = module.sftp_connector.connector_arn
}

output "connector_id" {
  description = "ID of the SFTP connector"
  value       = module.sftp_connector.connector_id
}

output "retrieve_bucket_name" {
  description = "Name of the S3 bucket for retrieved files"
  value       = module.retrieve_s3_bucket.s3_bucket_id
}

output "retrieve_bucket_arn" {
  description = "ARN of the S3 bucket for retrieved files"
  value       = module.retrieve_s3_bucket.s3_bucket_arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for tracking file transfers"
  value       = var.enable_dynamodb_tracking ? aws_dynamodb_table.file_transfer_tracking[0].name : null
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for tracking file transfers"
  value       = var.enable_dynamodb_tracking ? aws_dynamodb_table.file_transfer_tracking[0].arn : null
}

output "lambda_function_name" {
  description = "Name of the Lambda function for file discovery"
  value       = aws_lambda_function.file_discovery.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function for file discovery"
  value       = aws_lambda_function.file_discovery.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = local.kms_key_arn
}

output "eventbridge_schedule_name" {
  description = "Name of the EventBridge schedule"
  value       = aws_scheduler_schedule.lambda_trigger.name
}

output "eventbridge_schedule_arn" {
  description = "ARN of the EventBridge schedule"
  value       = aws_scheduler_schedule.lambda_trigger.arn
}

output "sftp_credentials_secret_arn" {
  description = "ARN of the SFTP credentials secret"
  value       = var.existing_secret_arn
}

output "connector_static_ips" {
  description = "Static IP addresses of the SFTP connector"
  value       = module.sftp_connector.connector_static_ips
}

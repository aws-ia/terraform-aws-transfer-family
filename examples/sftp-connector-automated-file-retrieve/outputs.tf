output "retrieve_bucket_name" {
  description = "The name of the S3 bucket for retrieved files"
  value       = module.retrieve_s3_bucket.s3_bucket_id
}

output "retrieve_bucket_arn" {
  description = "The ARN of the S3 bucket for retrieved files"
  value       = module.retrieve_s3_bucket.s3_bucket_arn
}

output "connector_id" {
  description = "The ID of the SFTP connector used for file retrieval"
  value       = var.connector_id != null ? var.connector_id : module.sftp_connector[0].connector_id
}

output "connector_arn" {
  description = "The ARN of the SFTP connector used for file retrieval"
  value       = var.connector_id != null ? null : module.sftp_connector[0].connector_arn
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table containing file paths"
  value       = aws_dynamodb_table.file_paths.name
}

output "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table containing file paths"
  value       = aws_dynamodb_table.file_paths.arn
}

output "lambda_function_name" {
  description = "The name of the Lambda function that retrieves files"
  value       = aws_lambda_function.sftp_retrieve.function_name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function that retrieves files"
  value       = aws_lambda_function.sftp_retrieve.arn
}

output "eventbridge_rule_name" {
  description = "The name of the EventBridge rule for scheduled retrieval"
  value       = aws_cloudwatch_event_rule.retrieve_schedule.name
}

output "eventbridge_rule_arn" {
  description = "The ARN of the EventBridge rule for scheduled retrieval"
  value       = aws_cloudwatch_event_rule.retrieve_schedule.arn
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = aws_kms_key.transfer_family_key.arn
}

output "sftp_credentials_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing SFTP credentials (if created)"
  value       = var.existing_secret_arn != null ? var.existing_secret_arn : (length(aws_secretsmanager_secret.sftp_credentials) > 0 ? aws_secretsmanager_secret.sftp_credentials[0].arn : null)
}

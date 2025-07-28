#####################################################################################
# Outputs for SFTP Connector Automated File Retrieve Workflow
#####################################################################################

# Transfer Family Server Outputs
output "server_id" {
  description = "The ID of the created Transfer Family server"
  value       = module.transfer_server.server_id
}

output "server_endpoint" {
  description = "The endpoint of the created Transfer Family server"
  value       = module.transfer_server.server_endpoint
}

# SFTP Connector Outputs
output "connector_id" {
  description = "The ID of the SFTP connector used for file retrieval"
  value       = local.workflow_connector_id
}

output "connector_arn" {
  description = "The ARN of the SFTP connector"
  value       = module.sftp_connector_auto_discovery.connector_arn
}

# S3 Bucket Outputs
output "sftp_server_bucket_name" {
  description = "The name of the S3 bucket used for SFTP server storage"
  value       = module.sftp_server_bucket.s3_bucket_id
}

output "sftp_server_bucket_arn" {
  description = "The ARN of the S3 bucket used for SFTP server storage"
  value       = module.sftp_server_bucket.s3_bucket_arn
}

output "file_retrieve_destination_bucket_name" {
  description = "The name of the S3 bucket where retrieved files are stored"
  value       = module.file_retrieve_destination_bucket.s3_bucket_id
}

output "file_retrieve_destination_bucket_arn" {
  description = "The ARN of the S3 bucket where retrieved files are stored"
  value       = module.file_retrieve_destination_bucket.s3_bucket_arn
}

# DynamoDB Table Outputs
output "dynamodb_table_name" {
  description = "The name of the DynamoDB table storing file paths for retrieval"
  value       = aws_dynamodb_table.file_paths.name
}

output "dynamodb_table_arn" {
  description = "The ARN of the DynamoDB table storing file paths for retrieval"
  value       = aws_dynamodb_table.file_paths.arn
}

# EventBridge Schedule Outputs
output "eventbridge_schedule_name" {
  description = "The name of the EventBridge schedule for automated file retrieval"
  value       = aws_scheduler_schedule.file_retrieve_schedule.name
}

output "eventbridge_schedule_arn" {
  description = "The ARN of the EventBridge schedule for automated file retrieval"
  value       = aws_scheduler_schedule.file_retrieve_schedule.arn
}

# Lambda Function Outputs
output "lambda_function_name" {
  description = "The name of the Lambda function that handles file retrieval"
  value       = aws_lambda_function.retrieve_files.function_name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function that handles file retrieval"
  value       = aws_lambda_function.retrieve_files.arn
}

# KMS Key Outputs
output "kms_key_id" {
  description = "The ID of the KMS key used for encryption"
  value       = aws_kms_key.transfer_family_key.key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = aws_kms_key.transfer_family_key.arn
}

output "kms_key_alias" {
  description = "The alias of the KMS key used for encryption"
  value       = aws_kms_alias.transfer_family_key_alias.name
}

# User Details Outputs
output "test_user_details" {
  description = "Details of the test user created for SFTP authentication"
  value       = module.sftp_users.test_user_created ? module.sftp_users.test_user_details : null
  sensitive   = true
}

output "user_details" {
  description = "Map of all users with their details including secret names and ARNs"
  value       = module.sftp_users.user_details
  sensitive   = true
}

# Workflow Configuration Outputs
output "workflow_configuration" {
  description = "Configuration details for the automated file retrieve workflow"
  value = {
    connector_id              = local.workflow_connector_id
    s3_destination_prefix     = var.s3_destination_prefix
    schedule_expression       = var.eventbridge_schedule_expression
    dynamodb_table_name       = aws_dynamodb_table.file_paths.name
    lambda_function_name      = aws_lambda_function.retrieve_files.function_name
    destination_bucket_name   = module.file_retrieve_destination_bucket.s3_bucket_id
  }
}

# Instructions for Usage
output "usage_instructions" {
  description = "Instructions for using the automated file retrieve workflow"
  value = {
    add_files_to_retrieve = "Add file paths to DynamoDB table '${aws_dynamodb_table.file_paths.name}' with status 'pending'"
    monitor_schedule      = "EventBridge schedule '${aws_scheduler_schedule.file_retrieve_schedule.name}' runs every ${var.eventbridge_schedule_expression}"
    check_retrieved_files = "Retrieved files will be stored in S3 bucket '${module.file_retrieve_destination_bucket.s3_bucket_id}' under prefix '${var.s3_destination_prefix}'"
    lambda_logs          = "Check CloudWatch logs for Lambda function '${aws_lambda_function.retrieve_files.function_name}' for execution details"
  }
}

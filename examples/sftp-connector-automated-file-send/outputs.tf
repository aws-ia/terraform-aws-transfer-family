#####################################################################################
# Outputs for SFTP Connector Example with Automated File Send Workflow
#####################################################################################

# Transfer Family Server outputs
output "transfer_server_id" {
  description = "The ID of the AWS Transfer Family server"
  value       = module.transfer_server.server_id
}

output "transfer_server_endpoint" {
  description = "The endpoint of the AWS Transfer Family server"
  value       = module.transfer_server.server_endpoint
}

# Auto-discovery connector outputs
output "auto_discovery_connector_id" {
  description = "The ID of the auto-discovery SFTP connector"
  value       = module.sftp_connector_auto_discovery.connector_id
}

output "auto_discovery_connector_arn" {
  description = "The ARN of the auto-discovery SFTP connector"
  value       = module.sftp_connector_auto_discovery.connector_arn
}

output "auto_discovery_secrets_manager_secret_name" {
  description = "The name of the Secrets Manager secret for auto-discovery connector"
  value       = module.sftp_connector_auto_discovery.secrets_manager_secret_name
}

# Manual keys connector outputs (if created)
output "manual_keys_connector_id" {
  description = "The ID of the manual keys SFTP connector"
  value       = length(module.sftp_connector_manual_keys) > 0 ? module.sftp_connector_manual_keys[0].connector_id : null
}

output "manual_keys_connector_arn" {
  description = "The ARN of the manual keys SFTP connector"
  value       = length(module.sftp_connector_manual_keys) > 0 ? module.sftp_connector_manual_keys[0].connector_arn : null
}

# S3 bucket information
output "sftp_server_bucket_name" {
  description = "The name of the S3 bucket used by the Transfer Family server"
  value       = module.sftp_server_bucket.s3_bucket_id
}

output "sftp_server_bucket_arn" {
  description = "The ARN of the S3 bucket used by the Transfer Family server"
  value       = module.sftp_server_bucket.s3_bucket_arn
}

output "file_send_source_bucket_name" {
  description = "The name of the S3 bucket monitored for automated file sending"
  value       = module.file_send_source_bucket.s3_bucket_id
}

output "file_send_source_bucket_arn" {
  description = "The ARN of the S3 bucket monitored for automated file sending"
  value       = module.file_send_source_bucket.s3_bucket_arn
}

# Automated File Send Workflow outputs
output "workflow_connector_id" {
  description = "The connector ID used by the automated file send workflow"
  value       = local.workflow_connector_id
}

output "eventbridge_rule_name" {
  description = "The name of the EventBridge rule that triggers file transfers"
  value       = aws_cloudwatch_event_rule.s3_file_send_trigger.name
}

output "eventbridge_rule_arn" {
  description = "The ARN of the EventBridge rule that triggers file transfers"
  value       = aws_cloudwatch_event_rule.s3_file_send_trigger.arn
}

output "lambda_role_arn" {
  description = "The ARN of the Lambda IAM role for file transfers"
  value       = aws_iam_role.lambda_transfer_role.arn
}

output "s3_monitoring_prefix" {
  description = "The S3 prefix being monitored for automated file sending"
  value       = var.s3_monitoring_prefix
}

output "remote_directory_path" {
  description = "The remote directory path where files are sent"
  value       = var.remote_directory_path
}

# KMS key information
output "kms_key_id" {
  description = "The ID of the KMS key used for encryption"
  value       = aws_kms_key.transfer_family_key.key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = aws_kms_key.transfer_family_key.arn
}

# IAM roles
output "auto_discovery_s3_access_role_arn" {
  description = "The ARN of the S3 access role for auto-discovery connector"
  value       = module.sftp_connector_auto_discovery.s3_access_role_arn
}

output "auto_discovery_logging_role_arn" {
  description = "The ARN of the logging role for auto-discovery connector"
  value       = module.sftp_connector_auto_discovery.logging_role_arn
}

# Configuration information
output "sftp_server_url" {
  description = "The SFTP server URL being connected to"
  value       = "sftp://${module.transfer_server.server_endpoint}"
}

output "auto_discovery_enabled" {
  description = "Whether auto-discovery is enabled for the main connector"
  value       = module.sftp_connector_auto_discovery.auto_discover_enabled
}

output "trusted_host_keys_provided" {
  description = "Whether trusted host keys were provided"
  value       = length(var.trusted_host_keys) > 0
}

output "max_concurrent_connections" {
  description = "Maximum concurrent connections configured"
  value       = var.max_concurrent_connections
}

output "security_policy_name" {
  description = "Security policy used by the connectors"
  value       = var.security_policy_name
}

# User information
output "test_user_created" {
  description = "Whether a test user was created on the Transfer Family server"
  value       = true  # The transfer-users module creates a test user by default
}

output "sftp_username" {
  description = "The SFTP username used for connector authentication"
  value       = var.sftp_username
}

# Workflow instructions
output "workflow_usage_instructions" {
  description = "Instructions for using the automated file send workflow"
  value = <<-EOT
    To trigger automated file transfers:
    1. Upload files to: s3://${module.file_send_source_bucket.s3_bucket_id}/${var.s3_monitoring_prefix}
    2. Files will automatically be sent to: ${var.remote_directory_path} on the SFTP server
    3. Monitor EventBridge rule: ${aws_cloudwatch_event_rule.s3_file_send_trigger.name}
    
    Example:
    aws s3 cp myfile.txt s3://${module.file_send_source_bucket.s3_bucket_id}/${var.s3_monitoring_prefix}myfile.txt
  EOT
}

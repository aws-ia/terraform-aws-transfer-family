output "server_id" {
  description = "The ID of the created Transfer Family server"
  value       = module.transfer_server.server_id
}

output "server_endpoint" {
  description = "The endpoint of the created Transfer Family server"
  value       = module.transfer_server.server_endpoint
}

output "sftp_bucket_name" {
  description = "The name of the S3 bucket used for SFTP storage"
  value       = module.s3_bucket.s3_bucket_id
}

output "sftp_bucket_arn" {
  description = "The ARN of the S3 bucket used for SFTP storage"
  value       = module.s3_bucket.s3_bucket_arn
}

output "connector_id" {
  description = "The ID of the AWS Transfer Family connector"
  value       = module.sftp_connector.connector_id
}

output "connector_arn" {
  description = "The ARN of the AWS Transfer Family connector"
  value       = module.sftp_connector.connector_arn
}

output "connector_url" {
  description = "The URL of the SFTP server the connector connects to"
  value       = module.sftp_connector.connector_url
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = aws_kms_key.transfer_family_key.arn
}

output "eventbridge_rule_arn" {
  description = "The ARN of the EventBridge rule for S3 object created events"
  value       = aws_cloudwatch_event_rule.s3_object_created.arn
}

output "test_bucket_name" {
  description = "The name of the test S3 bucket for uploading files to trigger SFTP transfers"
  value       = module.test_s3_bucket.s3_bucket_id
}

output "test_bucket_arn" {
  description = "The ARN of the test S3 bucket for uploading files to trigger SFTP transfers"
  value       = module.test_s3_bucket.s3_bucket_arn
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function that initiates SFTP transfers"
  value       = aws_lambda_function.sftp_transfer.arn
}

output "host_key_value" {
  description = "The host key value being used by the connector"
  value       = length(module.sftp_connector.effective_host_keys) > 0 ? trimspace(module.sftp_connector.effective_host_keys[0]) : ""
}

output "host_key_raw" {
  description = "All effective host keys for debugging"
  value       = module.sftp_connector.effective_host_keys
}
output "connector_scanned_host_keys" {
  description = "The SSH host keys scanned from the remote SFTP server"
  value       = module.sftp_connector.scanned_host_keys
}

output "connector_effective_host_keys" {
  description = "The actual host keys being used by the connector"
  value       = module.sftp_connector.effective_host_keys
}

output "connector_ssh_scanning_enabled" {
  description = "Whether SSH host key scanning was performed"
  value       = module.sftp_connector.ssh_scanning_enabled
}

output "connector_static_ips" {
  description = "Static IP addresses of the SFTP connector for whitelisting"
  value       = module.sftp_connector.connector_static_ips
}

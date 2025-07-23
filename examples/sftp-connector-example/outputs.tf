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

output "sftp_credentials_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing SFTP credentials"
  value       = aws_secretsmanager_secret.sftp_credentials.arn
}

output "eventbridge_rule_arn" {
  description = "The ARN of the EventBridge rule for S3 object created events"
  value       = aws_cloudwatch_event_rule.s3_object_created.arn
}

output "eventbridge_role_arn" {
  description = "The ARN of the IAM role used by EventBridge to initiate SFTP transfers"
  value       = aws_iam_role.eventbridge_transfer_role.arn
}

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

output "test_bucket_name" {
  description = "The name of the test S3 bucket for uploading files to trigger SFTP transfers"
  value       = module.test_s3_bucket.s3_bucket_id
}

output "test_bucket_arn" {
  description = "The ARN of the test S3 bucket for uploading files to trigger SFTP transfers"
  value       = module.test_s3_bucket.s3_bucket_arn
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = local.kms_key_arn
}

output "eventbridge_rule_arn" {
  description = "The ARN of the EventBridge rule for S3 object created events"
  value       = aws_cloudwatch_event_rule.s3_object_created.arn
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function that initiates SFTP transfers"
  value       = aws_lambda_function.sftp_transfer.arn
}

output "connector_static_ips" {
  description = "Static IP addresses of the SFTP connector"
  value       = module.sftp_connector.connector_static_ips
}

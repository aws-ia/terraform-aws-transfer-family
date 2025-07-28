#####################################################################################
# Outputs for AWS Transfer Family SFTP Connector Module
#####################################################################################

output "connector_id" {
  description = "The ID of the AWS Transfer Family connector"
  value       = local.active_connector.id
}

output "connector_arn" {
  description = "The ARN of the AWS Transfer Family connector"
  value       = local.active_connector.arn
}

output "connector_url" {
  description = "The URL of the SFTP server the connector connects to"
  value       = local.active_connector.url
}

output "s3_access_role_arn" {
  description = "The ARN of the IAM role used by the connector for S3 access"
  value       = local.s3_access_role_arn
}

output "logging_role_arn" {
  description = "The ARN of the IAM role used for connector logging"
  value       = local.logging_role_arn
}

output "secrets_manager_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing SFTP credentials"
  value       = aws_secretsmanager_secret.sftp_credentials.arn
}

output "secrets_manager_secret_name" {
  description = "The name of the Secrets Manager secret containing SFTP credentials"
  value       = aws_secretsmanager_secret.sftp_credentials.name
}

output "security_policy_name" {
  description = "The security policy used by the connector"
  value       = local.active_connector.security_policy_name
}

output "max_concurrent_connections" {
  description = "Maximum number of concurrent connections configured for the connector"
  value       = var.max_concurrent_connections
}

output "auto_discover_enabled" {
  description = "Whether auto-discovery of host keys is enabled"
  value       = local.should_auto_discover
}

output "trusted_host_keys_provided" {
  description = "Whether trusted host keys were provided by the user"
  value       = length(var.trusted_host_keys) > 0
}

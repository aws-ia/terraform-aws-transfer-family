#####################################################################################
# Outputs for AWS Transfer Family SFTP Connector Module
#####################################################################################

output "connector_id" {
  description = "The ID of the AWS Transfer Family connector"
  value       = aws_transfer_connector.sftp_connector.id
}

output "connector_arn" {
  description = "The ARN of the AWS Transfer Family connector"
  value       = aws_transfer_connector.sftp_connector.arn
}

output "connector_url" {
  description = "The URL of the SFTP server the connector connects to"
  value       = aws_transfer_connector.sftp_connector.url
}

output "connector_role_arn" {
  description = "The ARN of the IAM role used by the connector"
  value       = aws_iam_role.connector_role.arn
}

output "connector_logging_role_arn" {
  description = "The ARN of the IAM role used for connector logging (if created)"
  value       = var.logging_role != null ? var.logging_role : (length(aws_iam_role.connector_logging_role) > 0 ? aws_iam_role.connector_logging_role[0].arn : null)
}

output "scanned_host_keys" {
  description = "The SSH host keys scanned from the remote SFTP server (if scanning was performed)"
  value       = local.should_scan && length(data.external.ssh_host_keys) > 0 ? [data.external.ssh_host_keys[0].result.host_key] : []
}

output "effective_host_keys" {
  description = "The actual host keys being used by the connector (either scanned or provided)"
  value       = local.effective_host_keys
}

output "ssh_scanning_enabled" {
  description = "Whether SSH host key scanning was performed for this connector"
  value       = local.should_scan
}

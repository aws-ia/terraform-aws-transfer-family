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
  value       = var.access_role
}

output "connector_logging_role_arn" {
  description = "The ARN of the IAM role used for connector logging (if created)"
  value       = var.logging_role != null ? var.logging_role : (length(aws_iam_role.connector_logging_role) > 0 ? aws_iam_role.connector_logging_role[0].arn : null)
}

output "scanned_host_keys" {
  description = "The SSH host keys discovered from the remote SFTP server"
  value       = []
}

output "effective_host_keys" {
  description = "The actual host keys being used by the connector (either scanned or provided)"
  value       = var.trusted_host_keys
}

output "ssh_scanning_enabled" {
  description = "Whether SSH host key scanning was performed for this connector"
  value       = local.should_scan
}

output "connector_static_ips" {
  description = "Static IP addresses of the created SFTP connector (if available via AWS CLI)"
  value = {
    ip_addresses = data.external.connector_ips.result.ips != "" ? split(",", data.external.connector_ips.result.ips) : []
    status = data.external.connector_ips.result.status
    note = try(data.external.connector_ips.result.note, "")
  }
}

output "secret_arn" {
  description = "ARN of the created secret (if create_secret is true)"
  value       = local.create_secret ? aws_secretsmanager_secret.sftp_credentials[0].arn : null
}

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

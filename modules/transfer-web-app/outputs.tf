# Outputs for Transfer Web App Module

output "web_app_id" {
  description = "The ID of the Transfer web app"
  value       = aws_transfer_web_app.web_app.web_app_id
}

output "web_app_arn" {
  description = "The ARN of the Transfer web app"
  value       = aws_transfer_web_app.web_app.arn
}

output "web_app_access_endpoint" {
  description = "The access endpoint URL for the Transfer web app"
  value       = aws_transfer_web_app.web_app.access_endpoint
}

output "iam_role_arn" {
  description = "The ARN of the IAM role used by the Transfer web app"
  value       = aws_iam_role.transfer_web_app.arn
}

output "iam_role_name" {
  description = "The name of the IAM role used by the Transfer web app"
  value       = aws_iam_role.transfer_web_app.name
}

output "identity_store_group_ids" {
  description = "Map of Identity Store group names to their IDs"
  value = {
    for key, group in data.aws_identitystore_group.groups : key => group.group_id
  }
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail for audit logging"
  value       = var.enable_cloudtrail ? aws_cloudtrail.audit_trail[0].arn : null
}

output "application_arn" {
  description = "The ARN of the Identity Center application for the Transfer web app"
  value       = aws_transfer_web_app.web_app.identity_provider_details[0].identity_center_config[0].application_arn
}

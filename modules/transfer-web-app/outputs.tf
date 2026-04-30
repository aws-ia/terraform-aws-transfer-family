# Outputs for Transfer Web App Module

output "web_app_id" {
  description = "The ID of the Transfer web app"
  value       = aws_transfer_web_app.web_app.web_app_id
}

output "web_app_arn" {
  description = "The ARN of the Transfer web app"
  value       = aws_transfer_web_app.web_app.arn
}

output "web_app_endpoint" {
  description = "The web app endpoint URL for access and CORS configuration"
  value       = aws_transfer_web_app.web_app.access_endpoint
}

output "iam_role_arn" {
  description = "The ARN of the IAM role used by the Transfer web app"
  value       = local.web_app_role_arn
}

output "iam_role_name" {
  description = "The name of the IAM role used by the Transfer web app (only available when role is created by module)"
  value       = var.existing_web_app_iam_role_arn == null ? aws_iam_role.transfer_web_app[0].name : null
}

output "application_arn" {
  description = "The ARN of the Identity Center application for the Transfer web app"
  value       = aws_transfer_web_app.web_app.identity_provider_details[0].identity_center_config[0].application_arn
}

output "access_grants_instance_id" {
  description = "The ID of the S3 Access Grants instance"
  value       = local.access_grants_instance_id
}

output "access_grants_instance_arn" {
  description = "The ARN of the S3 Access Grants instance"
  value       = try(aws_s3control_access_grants_instance.instance[0].access_grants_instance_arn, null)
}

output "access_grants_location_role_arn" {
  description = "The ARN of the IAM role used by S3 Access Grants location (created or provided)"
  value       = local.access_grants_instance_id != null && (length(local.user_grants) > 0 || length(local.group_grants) > 0) && var.s3_access_grants_location_new != null && var.s3_access_grants_location_existing == null ? coalesce(var.s3_access_grants_location_iam_role_arn, try(aws_iam_role.access_grants_location[0].arn, null)) : null
}

output "access_grants_location_role_name" {
  description = "The name of the IAM role used by S3 Access Grants location (only available if created by module)"
  value       = try(aws_iam_role.access_grants_location[0].name, null)
}

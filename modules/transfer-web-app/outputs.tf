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
  value       = aws_iam_role.transfer_web_app.arn
}

output "iam_role_name" {
  description = "The name of the IAM role used by the Transfer web app"
  value       = aws_iam_role.transfer_web_app.name
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

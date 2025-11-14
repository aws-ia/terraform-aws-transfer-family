# Outputs for Transfer Web App Module

output "web_app_id" {
  description = "The ID of the Transfer web app"
  value       = aws_transfer_web_app.this.id
}

output "web_app_arn" {
  description = "The ARN of the Transfer web app"
  value       = aws_transfer_web_app.this.arn
}

output "web_app_access_endpoint" {
  description = "The access endpoint URL for the Transfer web app"
  value       = aws_transfer_web_app.this.access_endpoint
}

output "iam_role_arn" {
  description = "The ARN of the IAM role used by the Transfer web app"
  value       = aws_iam_role.transfer_web_app.arn
}

output "iam_role_name" {
  description = "The name of the IAM role used by the Transfer web app"
  value       = aws_iam_role.transfer_web_app.name
}

output "web_app_id" {
  description = "ID of the Transfer Family Web App"
  value       = awscc_transfer_web_app.main.web_app_id
}

output "web_app_arn" {
  description = "ARN of the Transfer Family Web App"
  value       = awscc_transfer_web_app.main.arn
}

output "web_app_endpoint" {
  description = "Endpoint URL of the Transfer Family Web App"
  value       = awscc_transfer_web_app.main.access_endpoint
}

output "bearer_role_arn" {
  description = "ARN of the Transfer Family Web App bearer role"
  value       = aws_iam_role.transfer_web_app.arn
}

output "access_grants_instance_arn" {
  description = "ARN of the S3 Access Grants instance"
  value       = var.access_grants_instance_arn
}

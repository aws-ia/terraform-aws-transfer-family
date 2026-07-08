# Cognito outputs
output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.cognito.user_pool_id
}

output "app_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = module.cognito.app_client_id
}

output "cognito_domain_url" {
  description = "Full Cognito hosted UI URL"
  value       = module.cognito.cognito_domain_url
}

output "cloudfront_url" {
  description = "Full URL of the CloudFront distribution"
  value       = module.cognito.cloudfront_url
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cognito.cloudfront_distribution_id
}

# Test user outputs
output "test_username" {
  description = "Username for the test user"
  value       = var.create_test_user ? var.test_username : null
}

output "test_user_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the test user password"
  value       = var.create_test_user ? aws_secretsmanager_secret.test_user_password[0].arn : null
}

# User Pool outputs
output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.endpoint
}

# App Client outputs
output "app_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.id
}

# Domain outputs
output "cognito_domain" {
  description = "Cognito domain prefix"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_domain_url" {
  description = "Full Cognito hosted UI URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.id}.amazoncognito.com"
}

# Landing page outputs
output "landing_page_bucket_id" {
  description = "ID of the S3 bucket hosting the landing page"
  value       = var.create_landing_page ? aws_s3_bucket.landing_page[0].id : null
}

output "landing_page_bucket_arn" {
  description = "ARN of the S3 bucket hosting the landing page"
  value       = var.create_landing_page ? aws_s3_bucket.landing_page[0].arn : null
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = var.create_landing_page ? aws_cloudfront_distribution.landing_page[0].id : null
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = var.create_landing_page ? aws_cloudfront_distribution.landing_page[0].arn : null
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = var.create_landing_page ? aws_cloudfront_distribution.landing_page[0].domain_name : null
}

output "cloudfront_url" {
  description = "Full URL of the CloudFront distribution"
  value       = var.create_landing_page ? "https://${aws_cloudfront_distribution.landing_page[0].domain_name}" : null
}

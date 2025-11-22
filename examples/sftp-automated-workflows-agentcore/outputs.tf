# Outputs - Conditional based on enabled stages

# Stage 0: Foundation outputs
output "identity_center_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  value       = var.enable_identity_center ? local.sso_instance_arn : null
}

output "identity_store_id" {
  description = "ID of the Identity Store"
  value       = var.enable_identity_center ? local.identity_store_id : null
}

output "s3_access_grants_instance_arn" {
  description = "ARN of the S3 Access Grants instance"
  value       = var.enable_s3_access_grants ? aws_s3control_access_grants_instance.main[0].access_grants_instance_arn : null
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = var.enable_cognito ? module.cognito[0].user_pool_id : null
}

output "cognito_username" {
  description = "Username for the Cognito user"
  value       = var.enable_cognito ? aws_cognito_user.anycompany[0].username : null
}

output "cognito_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the user password"
  value       = var.enable_cognito ? aws_secretsmanager_secret.cognito_user_password[0].arn : null
}

output "cloudfront_url" {
  description = "CloudFront distribution URL for the landing page"
  value       = var.enable_cognito ? module.cognito[0].cloudfront_url : null
}

# Stage 1: Transfer Server outputs
output "transfer_server_id" {
  description = "ID of the Transfer Family server"
  value       = var.enable_transfer_server && var.enable_custom_idp ? module.transfer_server[0].server_id : null
}

output "transfer_server_endpoint" {
  description = "Endpoint of the Transfer Family server"
  value       = var.enable_transfer_server && var.enable_custom_idp ? module.transfer_server[0].server_endpoint : null
}

output "transfer_s3_bucket_name" {
  description = "Name of the S3 bucket for Transfer Family"
  value       = var.enable_transfer_server ? module.s3_bucket_transfer[0].s3_bucket_id : null
}

output "lambda_function_name" {
  description = "Name of the Custom IDP Lambda function"
  value       = var.enable_custom_idp ? module.transfer_custom_idp[0].lambda_function_name : null
}

# Stage 2: Malware Protection outputs
output "malware_upload_bucket_name" {
  description = "Name of the upload bucket for malware scanning"
  value       = var.enable_malware_protection ? local.malware_source_bucket_id : null
}

output "malware_clean_bucket_name" {
  description = "Name of the clean bucket after malware scanning"
  value       = var.enable_malware_protection ? module.s3_bucket_clean[0].s3_bucket_id : null
}

output "malware_quarantine_bucket_name" {
  description = "Name of the quarantine bucket for infected files"
  value       = var.enable_malware_protection ? module.s3_bucket_quarantine[0].s3_bucket_id : null
}

# Stage 3: Agentcore outputs
output "agentcore_workflow_agent_runtime_id" {
  description = "ID of the workflow agent runtime"
  value       = var.enable_agentcore ? module.agentcore[0].workflow_agent_runtime_id : null
}

output "agentcore_claims_table_name" {
  description = "Name of the DynamoDB table for claims data"
  value       = var.enable_agentcore ? module.agentcore[0].claims_table_name : null
}

# Stage 4: Web App outputs
output "web_app_arn" {
  description = "ARN of the Transfer Family Web App"
  value       = var.enable_webapp ? module.transfer_webapp[0].web_app_arn : null
}

output "web_app_endpoint" {
  description = "Endpoint URL of the Transfer Family Web App"
  value       = var.enable_webapp ? module.transfer_webapp[0].web_app_endpoint : null
}



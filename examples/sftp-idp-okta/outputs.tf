output "server_id" {
  description = "The ID of the Transfer Family server"
  value       = module.transfer_server.server_id
}

output "server_endpoint" {
  description = "The endpoint of the Transfer Family server"
  value       = module.transfer_server.server_endpoint
}

output "okta_user_email" {
  description = "Email address of the Okta user"
  value       = var.okta_user_email
}

output "okta_domain" {
  description = "Okta domain for identity provider"
  value       = var.okta_domain
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  value       = module.s3_bucket.s3_bucket_id
}

output "identity_providers_table_name" {
  description = "Name of the DynamoDB identity providers table"
  value       = module.custom_idp.identity_providers_table_name
}

output "users_table_name" {
  description = "Name of the DynamoDB users table"
  value       = module.custom_idp.users_table_name
}

output "lambda_function_name" {
  description = "Name of the custom identity provider Lambda function"
  value       = module.custom_idp.lambda_function_name
}

output "connection_instructions" {
  description = "Instructions for connecting to the SFTP server"
  value = var.okta_mfa_required ? (
    <<-EOT
    Connect via SFTP using your existing Okta credentials with MFA:

    sftp ${var.okta_user_email}@${module.transfer_server.server_endpoint}

    When prompted for password, enter: YourOktaPassword + TOTP code
    Example: If password is "MyPass123" and TOTP is "456789", enter "MyPass123456789"
    EOT
  ) : (
    <<-EOT
    Connect via SFTP using your existing Okta credentials:

    sftp ${var.okta_user_email}@${module.transfer_server.server_endpoint}

    Use your Okta password when prompted.
    EOT
  )
}

output "server_id" {
  description = "The ID of the created Transfer Family server"
  value       = module.transfer_server.server_id
}

output "server_endpoint" {
  description = "The endpoint of the created Transfer Family server"
  value       = module.transfer_server.server_endpoint
}

output "lambda_function_arn" {
  description = "Custom IDP Lambda function ARN"
  value       = module.custom_idp.lambda_function_arn
}

output "lambda_function_name" {
  description = "Custom IDP Lambda function name"
  value       = module.custom_idp.lambda_function_name
}

output "users_table_name" {
  description = "DynamoDB users table name"
  value       = module.custom_idp.users_table_name
}

output "identity_providers_table_name" {
  description = "DynamoDB identity providers table name"
  value       = module.custom_idp.identity_providers_table_name
}

output "transfer_session_role_arn" {
  description = "ARN of the Transfer Family session role"
  value       = aws_iam_role.transfer_session.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket used for Transfer Family"
  value       = module.s3_bucket.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket used for Transfer Family"
  value       = module.s3_bucket.s3_bucket_arn
}

output "okta_domain" {
  description = "Okta domain used for authentication"
  value       = var.okta_domain
}

output "okta_user_id" {
  description = "ID of the Okta user"
  value       = data.okta_user.transfer_user.id
}

output "okta_user_email" {
  description = "Email address of the Okta user"
  value       = data.okta_user.transfer_user.email
}

output "connection_instructions" {
  description = "Instructions for connecting to the SFTP server"
  value       = <<-EOT
    SFTP Connection Instructions:

    1. Connect using your Okta credentials:
       sftp ${data.okta_user.transfer_user.email}@${module.transfer_server.server_endpoint}

    2. When prompted, enter your Okta password

    3. Once connected, you can upload/download files:
       sftp> put myfile.txt
       sftp> get myfile.txt
       sftp> ls
  EOT
}

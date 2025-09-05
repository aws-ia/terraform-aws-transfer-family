#####################################################################################
# Transfer Server Outputs
#####################################################################################

output "transfer_server_id" {
  description = "ID of the Transfer Family server"
  value       = module.transfer_server.server_id
}

output "transfer_server_endpoint" {
  description = "Endpoint hostname for SFTP connections"
  value       = module.transfer_server.server_endpoint
}

output "transfer_server_arn" {
  description = "ARN of the Transfer Family server"
  value       = "arn:aws:transfer:${var.aws_region}:${data.aws_caller_identity.current.account_id}:server/${module.transfer_server.server_id}"
}

#####################################################################################
# Custom IdP Outputs
#####################################################################################

output "lambda_function_name" {
  description = "Name of the custom IdP Lambda function"
  value       = module.custom_idp.lambda_function_name
}

output "api_gateway_url" {
  description = "URL of the API Gateway for custom IdP"
  value       = module.custom_idp.api_gateway_url
}

output "api_gateway_execution_role_arn" {
  description = "ARN of the API Gateway execution role"
  value       = module.custom_idp.api_gateway_execution_role_arn
}

#####################################################################################
# DynamoDB Outputs
#####################################################################################

output "users_table_name" {
  description = "Name of the DynamoDB users table"
  value       = module.custom_idp.users_table_name
}

output "identity_providers_table_name" {
  description = "Name of the DynamoDB identity providers table"
  value       = module.custom_idp.identity_providers_table_name
}

#####################################################################################
# Cognito Outputs
#####################################################################################

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.transfer_users.id
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.transfer_client.id
}

#####################################################################################
# S3 Outputs
#####################################################################################

output "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  value       = aws_s3_bucket.transfer_storage.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for file storage"
  value       = aws_s3_bucket.transfer_storage.arn
}

#####################################################################################
# CloudWatch Outputs
#####################################################################################

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.transfer_monitoring.dashboard_name}"
}

output "lambda_log_group_name" {
  description = "Name of the Lambda function CloudWatch log group"
  value       = module.custom_idp.lambda_log_group_name
}

#####################################################################################
# Connection Information
#####################################################################################

output "connection_instructions" {
  description = "Instructions for connecting to the SFTP server"
  value = {
    server_endpoint = module.transfer_server.server_endpoint
    admin_user = {
      username = var.test_user_1.username
      password = var.test_user_1.password
      access   = "Full bucket access"
    }
    regular_user = {
      username = var.test_user_2.username
      password = var.test_user_2.password
      access   = "Restricted to user directory"
    }
    example_commands = [
      "sftp ${var.test_user_1.username}@${module.transfer_server.server_endpoint}",
      "sftp ${var.test_user_2.username}@${module.transfer_server.server_endpoint}"
    ]
  }
  sensitive = true
}

#####################################################################################
# API Gateway Testing Information
#####################################################################################

output "api_gateway_test_info" {
  description = "Information for testing the API Gateway directly"
  value = {
    api_url = module.custom_idp.api_gateway_url
    test_endpoint = "${module.custom_idp.api_gateway_url}/servers/${module.transfer_server.server_id}/users/{username}/config"
    example_curl = "curl -X GET '${module.custom_idp.api_gateway_url}/servers/${module.transfer_server.server_id}/users/${var.test_user_1.username}/config?protocol=SFTP&sourceIp=127.0.0.1' -H 'PasswordBase64: $(echo -n '${var.test_user_1.password}' | base64)' --aws-sigv4 'aws:amz:${var.aws_region}:execute-api'"
  }
  sensitive = true
}
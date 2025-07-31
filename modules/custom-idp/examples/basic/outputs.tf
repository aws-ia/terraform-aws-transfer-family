# Outputs for basic usage example

# Custom IdP Module Outputs
output "lambda_function_arn" {
  description = "ARN of the custom IdP Lambda function"
  value       = module.transfer_custom_idp.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the custom IdP Lambda function"
  value       = module.transfer_custom_idp.lambda_function_name
}

output "users_table_name" {
  description = "Name of the DynamoDB users table"
  value       = module.transfer_custom_idp.users_table_name
}

output "users_table_arn" {
  description = "ARN of the DynamoDB users table"
  value       = module.transfer_custom_idp.users_table_arn
}

output "identity_providers_table_name" {
  description = "Name of the DynamoDB identity providers table"
  value       = module.transfer_custom_idp.identity_providers_table_name
}

output "identity_providers_table_arn" {
  description = "ARN of the DynamoDB identity providers table"
  value       = module.transfer_custom_idp.identity_providers_table_arn
}

# Transfer Server Outputs
output "transfer_server_id" {
  description = "ID of the AWS Transfer Family server"
  value       = aws_transfer_server.example.id
}

output "transfer_server_arn" {
  description = "ARN of the AWS Transfer Family server"
  value       = aws_transfer_server.example.arn
}

output "transfer_server_endpoint" {
  description = "Endpoint of the AWS Transfer Family server"
  value       = aws_transfer_server.example.endpoint
}

# Quick Start Information
output "next_steps" {
  description = "Next steps to configure the custom IdP solution"
  value = <<-EOT
    
    Basic deployment complete! Next steps:
    
    1. Configure Identity Providers in DynamoDB:
       Table: ${module.transfer_custom_idp.identity_providers_table_name}
       
    2. Add Users to DynamoDB:
       Table: ${module.transfer_custom_idp.users_table_name}
       
    3. Test the Transfer Server:
       Server ID: ${aws_transfer_server.example.id}
       Endpoint: ${aws_transfer_server.example.endpoint}
       
    4. View Lambda logs in CloudWatch:
       Log Group: /aws/lambda/${module.transfer_custom_idp.lambda_function_name}
       
    For detailed configuration instructions, see the module README.
  EOT
}
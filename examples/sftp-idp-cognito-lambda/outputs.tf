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
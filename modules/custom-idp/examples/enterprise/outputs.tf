# Outputs for enterprise usage example

# Custom IdP Module Outputs
output "lambda_function_arn" {
  description = "ARN of the custom IdP Lambda function"
  value       = module.transfer_custom_idp.lambda_function_arn
}

output "lambda_function_name" {
  description = "Name of the custom IdP Lambda function"
  value       = module.transfer_custom_idp.lambda_function_name
}

output "lambda_layer_arn" {
  description = "ARN of the Lambda layer"
  value       = module.transfer_custom_idp.lambda_layer_arn
}

output "lambda_log_group_name" {
  description = "Name of the Lambda CloudWatch log group"
  value       = module.transfer_custom_idp.lambda_log_group_name
}

# DynamoDB Outputs
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

# API Gateway Outputs (conditional)
output "api_gateway_url" {
  description = "URL of the API Gateway (if enabled)"
  value       = module.transfer_custom_idp.api_gateway_url
}

output "api_gateway_execution_role_arn" {
  description = "ARN of the API Gateway execution role (if enabled)"
  value       = module.transfer_custom_idp.api_gateway_execution_role_arn
}

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC used by Lambda function"
  value       = module.transfer_custom_idp.vpc_id
}

output "subnet_ids" {
  description = "List of subnet IDs used by Lambda function"
  value       = module.transfer_custom_idp.subnet_ids
}

output "security_group_ids" {
  description = "List of security group IDs used by Lambda function"
  value       = module.transfer_custom_idp.security_group_ids
}

# KMS Outputs
output "kms_key_id" {
  description = "ID of the KMS key used for encryption"
  value       = var.create_kms_key ? aws_kms_key.transfer_idp[0].key_id : var.existing_kms_key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = var.create_kms_key ? aws_kms_key.transfer_idp[0].arn : var.existing_kms_key_id
}

output "kms_alias_name" {
  description = "Name of the KMS key alias"
  value       = var.create_kms_key ? aws_kms_alias.transfer_idp[0].name : null
}

# Transfer Server Outputs
output "transfer_server_id" {
  description = "ID of the AWS Transfer Family server"
  value       = var.enable_api_gateway ? aws_transfer_server.enterprise[0].id : aws_transfer_server.enterprise_lambda[0].id
}

output "transfer_server_arn" {
  description = "ARN of the AWS Transfer Family server"
  value       = var.enable_api_gateway ? aws_transfer_server.enterprise[0].arn : aws_transfer_server.enterprise_lambda[0].arn
}

output "transfer_server_endpoint" {
  description = "Endpoint of the AWS Transfer Family server"
  value       = var.enable_api_gateway ? aws_transfer_server.enterprise[0].endpoint : aws_transfer_server.enterprise_lambda[0].endpoint
}

output "transfer_integration_type" {
  description = "Integration type used for Transfer Family server"
  value       = var.enable_api_gateway ? "API_Gateway" : "Lambda"
}

# Monitoring Outputs
output "cloudwatch_alarms" {
  description = "List of CloudWatch alarm names created for monitoring"
  value = var.enable_monitoring ? [
    aws_cloudwatch_metric_alarm.lambda_errors[0].alarm_name,
    aws_cloudwatch_metric_alarm.lambda_duration[0].alarm_name,
    aws_cloudwatch_metric_alarm.dynamodb_throttles[0].alarm_name
  ] : []
}

output "transfer_log_group_name" {
  description = "Name of the Transfer Family CloudWatch log group"
  value       = var.enable_structured_logging ? aws_cloudwatch_log_group.transfer_logs[0].name : null
}

output "transfer_log_group_arn" {
  description = "ARN of the Transfer Family CloudWatch log group"
  value       = var.enable_structured_logging ? aws_cloudwatch_log_group.transfer_logs[0].arn : null
}

# Enterprise Configuration Summary
output "enterprise_features_enabled" {
  description = "Summary of enterprise features enabled in this deployment"
  value = {
    api_gateway         = var.enable_api_gateway
    xray_tracing       = var.enable_xray_tracing
    kms_encryption     = var.create_kms_key || var.existing_kms_key_id != null
    vpc_integration    = var.use_existing_vpc
    monitoring_alarms  = var.enable_monitoring
    structured_logging = var.enable_structured_logging
    point_in_time_recovery = true
    secrets_manager_permissions = true
  }
}

# Quick Start Information
output "enterprise_deployment_summary" {
  description = "Enterprise deployment summary and next steps"
  value = <<-EOT
    
    Enterprise deployment complete! Configuration summary:
    
    🏢 ENTERPRISE FEATURES ENABLED:
    ├── Integration: ${var.enable_api_gateway ? "API Gateway" : "Lambda"}
    ├── VPC: ${var.use_existing_vpc ? "Existing VPC" : "No VPC"}
    ├── Encryption: ${var.create_kms_key ? "Custom KMS Key" : "AWS Managed"}
    ├── Monitoring: ${var.enable_monitoring ? "CloudWatch Alarms" : "Basic"}
    ├── Tracing: ${var.enable_xray_tracing ? "X-Ray Enabled" : "Disabled"}
    └── Logging: ${var.enable_structured_logging ? "Structured" : "Basic"}
    
    📊 RESOURCES CREATED:
    ├── Transfer Server: ${var.enable_api_gateway ? aws_transfer_server.enterprise[0].id : aws_transfer_server.enterprise_lambda[0].id}
    ├── Lambda Function: ${module.transfer_custom_idp.lambda_function_name}
    ├── Users Table: ${module.transfer_custom_idp.users_table_name}
    ├── Providers Table: ${module.transfer_custom_idp.identity_providers_table_name}
    ${var.create_kms_key ? "├── KMS Key: ${aws_kms_key.transfer_idp[0].key_id}" : ""}
    ${var.enable_monitoring ? "└── CloudWatch Alarms: ${length(var.enable_monitoring ? [aws_cloudwatch_metric_alarm.lambda_errors[0].alarm_name, aws_cloudwatch_metric_alarm.lambda_duration[0].alarm_name, aws_cloudwatch_metric_alarm.dynamodb_throttles[0].alarm_name] : [])} alarms" : ""}
    
    🔧 NEXT STEPS:
    1. Configure identity providers in: ${module.transfer_custom_idp.identity_providers_table_name}
    2. Add users to: ${module.transfer_custom_idp.users_table_name}
    3. Test connection: ${var.enable_api_gateway ? aws_transfer_server.enterprise[0].endpoint : aws_transfer_server.enterprise_lambda[0].endpoint}
    4. Monitor logs: ${module.transfer_custom_idp.lambda_log_group_name}
    ${var.enable_monitoring && var.sns_alarm_topic_arn != null ? "5. Check alarm notifications: ${var.sns_alarm_topic_arn}" : ""}
    
    📚 For detailed configuration, see the enterprise example README.
  EOT
}
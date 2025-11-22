# Workflow Agent Runtime ID for testing
output "workflow_agent_runtime_id" {
  description = "ID of the workflow agent runtime"
  value       = module.workflow_agent.agent_runtime_id
}

# Test payload
output "test_payload" {
  description = "Test payload for the workflow agent"
  value = jsonencode({
    bucket    = var.bucket_name
    pdf_key   = "claim-2/car_damage_claim_report.pdf"
    image_key = "claim-2/claim-2.png"
  })
}

# Lambda and EventBridge outputs
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.claims_processor.function_name
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.s3_upload_rule.name
}

output "trigger_instructions" {
  description = "Instructions for triggering the workflow"
  value       = "Upload PDF files to s3://${var.bucket_name}/claim-X/ to automatically trigger claims processing"
}

# DynamoDB Claims Table
output "claims_table_name" {
  description = "Name of the DynamoDB claims table"
  value       = aws_dynamodb_table.claims.name
}

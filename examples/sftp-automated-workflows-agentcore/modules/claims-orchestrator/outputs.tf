output "function_name" {
  description = "Name of the orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.function_name
}

output "function_arn" {
  description = "ARN of the orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.arn
}

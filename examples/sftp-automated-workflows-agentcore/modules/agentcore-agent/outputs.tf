output "agent_runtime_id" {
  description = "ID of the AgentCore agent runtime"
  value       = aws_bedrockagentcore_agent_runtime.agentcore_runtime.agent_runtime_id
}

output "agent_runtime_arn" {
  description = "ARN of the AgentCore agent runtime"
  value       = aws_bedrockagentcore_agent_runtime.agentcore_runtime.agent_runtime_arn
}

output "agent_runtime_name" {
  description = "Name of the AgentCore agent runtime"
  value       = aws_bedrockagentcore_agent_runtime.agentcore_runtime.agent_runtime_name
}

output "execution_role_arn" {
  description = "ARN of the agent execution IAM role"
  value       = aws_iam_role.execution.arn
}

output "execution_role_name" {
  description = "Name of the agent execution IAM role (for attaching additional policies)"
  value       = aws_iam_role.execution.name
}

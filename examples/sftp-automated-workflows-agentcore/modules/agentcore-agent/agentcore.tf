resource "aws_bedrockagentcore_agent_runtime" "agentcore_runtime" {
  agent_runtime_name = local.runtime_name
  role_arn           = aws_iam_role.execution.arn

  agent_runtime_artifact {
    code_configuration {
      entry_point = var.entry_point
      runtime     = var.python_runtime

      code {
        s3 {
          bucket = var.code_bucket_id
          prefix = aws_s3_object.agent_code.key
        }
      }
    }
  }

  network_configuration {
    network_mode = var.network_mode
  }

  protocol_configuration {
    server_protocol = var.server_protocol
  }

  environment_variables = merge(var.environment_variables, { "SOURCE_CONTENT_HASH" = local.source_content_hash })

  depends_on = [
    aws_iam_role_policy.bedrock_invoke,
    aws_iam_role_policy.cloudwatch_logs,
    aws_iam_role_policy.s3_read,
    aws_iam_role_policy.xray_traces,
    aws_iam_role_policy.invoke_gateway,
    aws_s3_object.agent_code,
  ]

  tags = var.tags
}
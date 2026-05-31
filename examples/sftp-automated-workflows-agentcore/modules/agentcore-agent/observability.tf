# ─────────────────────────────────────────────────────────────────────────────
# Observability — CloudWatch Logs delivery for AgentCore Runtime
# Sets up vended log delivery (APPLICATION_LOGS + USAGE_LOGS + TRACES) so that
# agent traces and logs appear in CloudWatch and the GenAI Observability
# dashboard. Gated by var.enable_agentcore_observability — requires CloudWatch Transaction
# Search to be enabled at the account level first.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  runtime_id  = aws_bedrockagentcore_agent_runtime.agentcore_runtime.agent_runtime_id
  runtime_arn = aws_bedrockagentcore_agent_runtime.agentcore_runtime.agent_runtime_arn
}

# ── Log group for vended logs ────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "agent_logs" {
  #checkov:skip=CKV_AWS_338: "Demo example — 30-day retention is acceptable"
  #checkov:skip=CKV_AWS_158: "Using AWS managed encryption is acceptable for this use case"
  count             = var.enable_agentcore_observability ? 1 : 0
  name              = "/aws/vendedlogs/bedrock-agentcore/runtimes/${local.runtime_id}"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_resource_policy" "agent_logs" {
  count       = var.enable_agentcore_observability ? 1 : 0
  policy_name = "${local.resource_name}-log-delivery"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AWSLogDeliveryWrite"
      Effect = "Allow"
      Principal = {
        Service = "delivery.logs.amazonaws.com"
      }
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.agent_logs[0].arn}:log-stream:*"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })
}

# ── Delivery source (the runtime itself) — APPLICATION_LOGS ──────────────────

resource "aws_cloudwatch_log_delivery_source" "app_logs" {
  count        = var.enable_agentcore_observability ? 1 : 0
  name         = "${local.resource_name}-app-logs"
  log_type     = "APPLICATION_LOGS"
  resource_arn = local.runtime_arn
}

# ── Delivery destination (CloudWatch log group) ──────────────────────────────

resource "aws_cloudwatch_log_delivery_destination" "app_logs" {
  count = var.enable_agentcore_observability ? 1 : 0
  name  = "${local.resource_name}-app-logs"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.agent_logs[0].arn
  }

  depends_on = [aws_cloudwatch_log_resource_policy.agent_logs]
}

# ── Delivery (links source → destination) ────────────────────────────────────

resource "aws_cloudwatch_log_delivery" "app_logs" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.app_logs[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.app_logs[0].name
}

# ── Delivery source (the runtime itself) — USAGE_LOGS ────────────────────────

resource "aws_cloudwatch_log_delivery_source" "usage_logs" {
  count        = var.enable_agentcore_observability ? 1 : 0
  name         = "${local.resource_name}-usage-logs"
  log_type     = "USAGE_LOGS"
  resource_arn = local.runtime_arn

  depends_on = [aws_cloudwatch_log_delivery.app_logs]
}

# ── Delivery destination (same log group) — USAGE_LOGS ───────────────────────

resource "aws_cloudwatch_log_delivery_destination" "usage_logs" {
  count = var.enable_agentcore_observability ? 1 : 0
  name  = "${local.resource_name}-usage-logs"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.agent_logs[0].arn
  }

  depends_on = [aws_cloudwatch_log_resource_policy.agent_logs]
}

# ── Delivery (links usage source → destination) ──────────────────────────────

resource "aws_cloudwatch_log_delivery" "usage_logs" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.usage_logs[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.usage_logs[0].name

  depends_on = [aws_cloudwatch_log_delivery.app_logs]
}

# ── Delivery source — TRACES ─────────────────────────────────────────────────

resource "aws_cloudwatch_log_delivery_source" "traces" {
  count        = var.enable_agentcore_observability ? 1 : 0
  name         = "${local.resource_name}-traces"
  log_type     = "TRACES"
  resource_arn = local.runtime_arn

  depends_on = [aws_cloudwatch_log_delivery.usage_logs]
}

# ── Delivery destination — X-Ray ─────────────────────────────────────────────

resource "aws_cloudwatch_log_delivery_destination" "traces" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  name                     = "${local.resource_name}-traces"
  delivery_destination_type = "XRAY"
}

# ── Delivery (links traces source → X-Ray destination) ───────────────────────

resource "aws_cloudwatch_log_delivery" "traces" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.traces[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.traces[0].name

  depends_on = [aws_cloudwatch_log_delivery.usage_logs]
}

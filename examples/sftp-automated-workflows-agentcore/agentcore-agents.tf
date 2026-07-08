################################################################################
# AgentCore Agent Runtimes
# Components: Agent code bucket + 4 AgentCore agent runtimes
#
# The agents themselves are created here so their (slow) build step runs as
# part of the foundation. Data-bucket permissions and gateway wiring are
# attached later, each as its prerequisite comes online:
#   - Data-bucket access (the clean bucket) lands once
#     enable_malware_protection creates module.s3_bucket_clean (in
#     malware-protection.tf).
#   - Gateway invoke permission lands once enable_agentcore creates the MCP
#     gateway (in ai-orchestration.tf).
# In stage 0 the agents exist but have no access to the clean bucket or the
# MCP gateway.
#
# Stage 0 apply:
#   - 4 agent runtimes (base env: AWS_REGION only; no gateway, no data IAM)
#   - agent_code_bucket holding the zipped agent code for each runtime
#
# Stage 2 apply (when enable_malware_protection = true) will:
#   - Attach data_bucket_arns = [s3_bucket_clean.arn] → creates data-bucket IAM
#     policy + adds CLAIMS_BUCKET env var on all 4 agents (in-place update)
#
# Stage 3 apply (when enable_agentcore = true) will:
#   - For the 3 gateway-using agents (damage_assessment, fraud_detection,
#     classification), flip enable_gateway = true → creates invoke-gateway IAM
#     policy + adds AGENTCORE_GATEWAY_URL env var (in-place update).
#     document_extraction_agent is unchanged — it reads S3 directly via boto3.
################################################################################

locals {
  agentcore_name_prefix = "tf-demo"

  # Clean-bucket ARN/name surface for agent modules. Resolves to the real values
  # once stage 2 is applied; before that, modules get an empty list / no env var.
  agentcore_clean_bucket_arn = try(module.s3_bucket_clean[0].s3_bucket_arn, "")
  agentcore_clean_bucket_id  = try(module.s3_bucket_clean[0].s3_bucket_id, "")

  # Gateway surface. Resolves once stage 3's gateway resource exists.
  agentcore_gateway_arn = try(aws_bedrockagentcore_gateway.claims_reader[0].gateway_arn, "")
  agentcore_gateway_url = try(aws_bedrockagentcore_gateway.claims_reader[0].gateway_url, "")

  # Base env vars every agent gets (stage 0 onward).
  agentcore_base_env = {
    AWS_REGION = var.aws_region
  }

  # Env vars that become non-empty once the clean bucket exists (stage 2 onward).
  agentcore_data_env = var.enable_malware_protection ? {
    CLAIMS_BUCKET = local.agentcore_clean_bucket_id
  } : {}

  # Env vars that become non-empty once the gateway exists (stage 3 onward).
  agentcore_gateway_env = var.enable_agentcore ? {
    AGENTCORE_GATEWAY_URL = local.agentcore_gateway_url
  } : {}

  # Data-bucket ARN list for agent IAM (empty until stage 2).
  agentcore_data_bucket_arns = var.enable_malware_protection ? [local.agentcore_clean_bucket_arn] : []
}

resource "random_id" "agentcore" {
  count       = var.enable_agentcore_agents ? 1 : 0
  byte_length = 4
}

# ── S3 bucket for agent code packages ────────────────────────────────────────

module "agent_code_bucket" {
  count  = var.enable_agentcore_agents ? 1 : 0
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v5.0.0"

  bucket                   = lower("${local.agentcore_name_prefix}-agent-code-${random_id.agentcore[0].hex}")
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true
  force_destroy            = true

  versioning = {
    enabled = true
  }
}

# ── Document Extraction Agent (no gateway — reads S3 directly via boto3) ─────

module "document_extraction_agent" {
  count  = var.enable_agentcore_agents ? 1 : 0
  source = "./modules/agentcore-agent"

  name_prefix      = local.agentcore_name_prefix
  agent_name       = "document-extraction-agent"
  agent_source_dir = "${path.module}/agent-source-code/document_extraction_agent"
  entry_point      = ["opentelemetry-instrument", "main.py"]

  code_bucket_id  = module.agent_code_bucket[0].s3_bucket_id
  code_bucket_arn = module.agent_code_bucket[0].s3_bucket_arn

  data_bucket_arns = local.agentcore_data_bucket_arns

  environment_variables = merge(
    local.agentcore_base_env,
    local.agentcore_data_env,
  )

  tags = var.tags
}

# ── Damage Assessment Agent (uses gateway when enable_agentcore) ─────────────

module "damage_assessment_agent" {
  count  = var.enable_agentcore_agents ? 1 : 0
  source = "./modules/agentcore-agent"

  name_prefix      = local.agentcore_name_prefix
  agent_name       = "damage-assessment-agent"
  agent_source_dir = "${path.module}/agent-source-code/damage_assessment_agent"
  entry_point      = ["opentelemetry-instrument", "main.py"]

  code_bucket_id  = module.agent_code_bucket[0].s3_bucket_id
  code_bucket_arn = module.agent_code_bucket[0].s3_bucket_arn

  enable_gateway = var.enable_agentcore
  gateway_arn    = local.agentcore_gateway_arn

  data_bucket_arns = local.agentcore_data_bucket_arns

  environment_variables = merge(
    local.agentcore_base_env,
    local.agentcore_data_env,
    local.agentcore_gateway_env,
  )

  tags = var.tags
}

# ── Fraud Detection Agent (uses gateway when enable_agentcore) ───────────────

module "fraud_detection_agent" {
  count  = var.enable_agentcore_agents ? 1 : 0
  source = "./modules/agentcore-agent"

  name_prefix      = local.agentcore_name_prefix
  agent_name       = "fraud-detection-agent"
  agent_source_dir = "${path.module}/agent-source-code/fraud_detection_agent"
  entry_point      = ["opentelemetry-instrument", "main.py"]

  code_bucket_id  = module.agent_code_bucket[0].s3_bucket_id
  code_bucket_arn = module.agent_code_bucket[0].s3_bucket_arn

  enable_gateway = var.enable_agentcore
  gateway_arn    = local.agentcore_gateway_arn

  data_bucket_arns = local.agentcore_data_bucket_arns

  environment_variables = merge(
    local.agentcore_base_env,
    local.agentcore_data_env,
    local.agentcore_gateway_env,
  )

  tags = var.tags
}

# ── Classification Agent (uses gateway when enable_agentcore) ────────────────

module "classification_agent" {
  count  = var.enable_agentcore_agents ? 1 : 0
  source = "./modules/agentcore-agent"

  name_prefix      = local.agentcore_name_prefix
  agent_name       = "classification-agent"
  agent_source_dir = "${path.module}/agent-source-code/classification_agent"
  entry_point      = ["opentelemetry-instrument", "main.py"]

  code_bucket_id  = module.agent_code_bucket[0].s3_bucket_id
  code_bucket_arn = module.agent_code_bucket[0].s3_bucket_arn

  enable_gateway = var.enable_agentcore
  gateway_arn    = local.agentcore_gateway_arn

  data_bucket_arns = local.agentcore_data_bucket_arns

  environment_variables = merge(
    local.agentcore_base_env,
    local.agentcore_data_env,
    local.agentcore_gateway_env,
  )

  tags = var.tags
}

################################################################################
# Observability — CloudWatch Transaction Search + Agent Log/Trace Delivery
#
# Enables Transaction Search (required for AgentCore trace delivery) and sets
# up vended log delivery (APPLICATION_LOGS + USAGE_LOGS + TRACES) for each
# agent runtime. Resources are chained sequentially to avoid concurrent
# CreateDelivery API conflicts.
#
# Reference: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Enable-TransactionSearch.html
################################################################################

locals {
  # Agent runtime references for observability (empty when agents disabled)
  observability_agents = var.enable_agentcore_agents && var.enable_agentcore_observability ? {
    extraction     = module.document_extraction_agent[0]
    damage         = module.damage_assessment_agent[0]
    fraud          = module.fraud_detection_agent[0]
    classification = module.classification_agent[0]
  } : {}
}

# ── Transaction Search (account-level) ───────────────────────────────────────

resource "aws_cloudwatch_log_resource_policy" "xray_transaction_search" {
  count       = var.enable_agentcore_observability ? 1 : 0
  policy_name = "${local.agentcore_name_prefix}-xray-transaction-search"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "TransactionSearchXRayAccess"
      Effect = "Allow"
      Principal = {
        Service = "xray.amazonaws.com"
      }
      Action = "logs:PutLogEvents"
      Resource = [
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:aws/spans:*",
        "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/application-signals/data:*"
      ]
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:xray:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        }
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_xray_trace_segment_destination" "cloudwatch" {
  count       = var.enable_agentcore_observability ? 1 : 0
  destination = "CloudWatchLogs"

  depends_on = [aws_cloudwatch_log_resource_policy.xray_transaction_search]
}

resource "aws_xray_indexing_rule" "default" {
  count = var.enable_agentcore_observability ? 1 : 0
  name  = "Default"

  rule {
    probabilistic {
      desired_sampling_percentage = 1.0
    }
  }

  depends_on = [aws_xray_trace_segment_destination.cloudwatch]
}

# ── Per-agent log delivery (chained to avoid concurrent API conflicts) ───────

resource "aws_cloudwatch_log_group" "agent_observability" {
  #checkov:skip=CKV_AWS_338: "Demo example — 30-day retention is acceptable"
  #checkov:skip=CKV_AWS_158: "Using AWS managed encryption is acceptable for this use case"
  for_each          = local.observability_agents
  name              = "/aws/vendedlogs/bedrock-agentcore/runtimes/${each.value.agent_runtime_id}"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_cloudwatch_log_resource_policy" "agent_log_delivery" {
  count       = var.enable_agentcore_observability ? 1 : 0
  policy_name = "${local.agentcore_name_prefix}-agent-log-delivery"

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
      Resource = [for lg in aws_cloudwatch_log_group.agent_observability : "${lg.arn}:log-stream:*"]
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })
}

# APPLICATION_LOGS delivery — one per agent, chained sequentially
resource "aws_cloudwatch_log_delivery_source" "app_logs" {
  for_each     = local.observability_agents
  name         = "${local.agentcore_name_prefix}-${each.key}-app-logs"
  log_type     = "APPLICATION_LOGS"
  resource_arn = each.value.agent_runtime_arn

  depends_on = [aws_xray_indexing_rule.default]
}

resource "aws_cloudwatch_log_delivery_destination" "app_logs" {
  for_each = local.observability_agents
  name     = "${local.agentcore_name_prefix}-${each.key}-app-logs"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.agent_observability[each.key].arn
  }

  depends_on = [aws_cloudwatch_log_resource_policy.agent_log_delivery]
}

resource "aws_cloudwatch_log_delivery" "app_logs_extraction" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.app_logs["extraction"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.app_logs["extraction"].name

  depends_on = [aws_xray_indexing_rule.default]
}

resource "aws_cloudwatch_log_delivery" "app_logs_damage" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.app_logs["damage"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.app_logs["damage"].name

  depends_on = [aws_cloudwatch_log_delivery.app_logs_extraction]
}

resource "aws_cloudwatch_log_delivery" "app_logs_fraud" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.app_logs["fraud"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.app_logs["fraud"].name

  depends_on = [aws_cloudwatch_log_delivery.app_logs_damage]
}

resource "aws_cloudwatch_log_delivery" "app_logs_classification" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.app_logs["classification"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.app_logs["classification"].name

  depends_on = [aws_cloudwatch_log_delivery.app_logs_fraud]
}

# USAGE_LOGS delivery — chained after app_logs
resource "aws_cloudwatch_log_delivery_source" "usage_logs" {
  for_each     = local.observability_agents
  name         = "${local.agentcore_name_prefix}-${each.key}-usage-logs"
  log_type     = "USAGE_LOGS"
  resource_arn = each.value.agent_runtime_arn

  depends_on = [aws_cloudwatch_log_delivery.app_logs_classification]
}

resource "aws_cloudwatch_log_delivery_destination" "usage_logs" {
  for_each = local.observability_agents
  name     = "${local.agentcore_name_prefix}-${each.key}-usage-logs"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.agent_observability[each.key].arn
  }

  depends_on = [aws_cloudwatch_log_resource_policy.agent_log_delivery]
}

resource "aws_cloudwatch_log_delivery" "usage_logs_extraction" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.usage_logs["extraction"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.usage_logs["extraction"].name

  depends_on = [aws_cloudwatch_log_delivery.app_logs_classification]
}

resource "aws_cloudwatch_log_delivery" "usage_logs_damage" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.usage_logs["damage"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.usage_logs["damage"].name

  depends_on = [aws_cloudwatch_log_delivery.usage_logs_extraction]
}

resource "aws_cloudwatch_log_delivery" "usage_logs_fraud" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.usage_logs["fraud"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.usage_logs["fraud"].name

  depends_on = [aws_cloudwatch_log_delivery.usage_logs_damage]
}

resource "aws_cloudwatch_log_delivery" "usage_logs_classification" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.usage_logs["classification"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.usage_logs["classification"].name

  depends_on = [aws_cloudwatch_log_delivery.usage_logs_fraud]
}

# TRACES delivery — chained after usage_logs
resource "aws_cloudwatch_log_delivery_source" "traces" {
  for_each     = local.observability_agents
  name         = "${local.agentcore_name_prefix}-${each.key}-traces"
  log_type     = "TRACES"
  resource_arn = each.value.agent_runtime_arn

  depends_on = [aws_cloudwatch_log_delivery.usage_logs_classification]
}

resource "aws_cloudwatch_log_delivery_destination" "traces" {
  for_each                 = local.observability_agents
  name                     = "${local.agentcore_name_prefix}-${each.key}-traces"
  delivery_destination_type = "XRAY"

  depends_on = [aws_xray_indexing_rule.default]
}

resource "aws_cloudwatch_log_delivery" "traces_extraction" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.traces["extraction"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.traces["extraction"].name

  depends_on = [aws_cloudwatch_log_delivery.usage_logs_classification]
}

resource "aws_cloudwatch_log_delivery" "traces_damage" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.traces["damage"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.traces["damage"].name

  depends_on = [aws_cloudwatch_log_delivery.traces_extraction]
}

resource "aws_cloudwatch_log_delivery" "traces_fraud" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.traces["fraud"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.traces["fraud"].name

  depends_on = [aws_cloudwatch_log_delivery.traces_damage]
}

resource "aws_cloudwatch_log_delivery" "traces_classification" {
  count                    = var.enable_agentcore_observability ? 1 : 0
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.traces["classification"].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.traces["classification"].name

  depends_on = [aws_cloudwatch_log_delivery.traces_fraud]
}

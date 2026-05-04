################################################################################
# Stage 0: AgentCore Agent Runtimes
# Components: Agent code bucket + 4 AgentCore agent runtimes
#
# The agents themselves are created in stage 0 so their (slow) build step runs
# as part of the foundation stage rather than during the AI-processing stage.
# Data-bucket permissions and gateway wiring are attached later in stage 3
# (see stage3-agentcore.tf) — in stage 0 the agents exist but have no access
# to the clean bucket or the MCP gateway.
#
# Stage 0 apply:
#   - 4 agent runtimes at version 1 (minimal env vars, no gateway, no data IAM)
#   - agent_code_bucket holding the zipped agent code for each runtime
#
# Stage 3 apply (when enable_agentcore = true) will:
#   - Attach data_bucket_arns = [s3_bucket_clean.arn] → creates data-bucket IAM
#     policy + bumps runtimes to version 2 with CLAIMS_BUCKET env var
#   - For the 3 gateway-using agents, flip enable_gateway = true → creates
#     invoke-gateway IAM policy + adds AGENTCORE_GATEWAY_URL env var
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
  entry_point      = ["main.py"]

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
  entry_point      = ["main.py"]

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
  entry_point      = ["main.py"]

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
  entry_point      = ["main.py"]

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

################################################################################
# Stage 3: Claims Processing Pipeline
# Components: MCP Gateway + Claims Reader Lambda + DynamoDB + Orchestrator
#
# The AgentCore agent runtimes themselves are created in stage 0
# (see stage0-agentcore-agents.tf). This stage wires them into the data plane:
#
#   - DynamoDB table for claim records
#   - MCP gateway + Lambda backend that gives 3 of the 4 agents access to
#     get_claim_data / get_claim_photos tools
#   - Orchestrator Lambda that watches the clean bucket for claim zips and
#     runs the agents through their pipeline stages
#
# Applying this stage with enable_agentcore = true will also update the 4
# agent runtimes (via the stage 0 module calls, whose inputs now resolve
# to non-empty values): data-bucket IAM + CLAIMS_BUCKET env var for all 4,
# and invoke-gateway IAM + AGENTCORE_GATEWAY_URL env var for the 3 gateway
# users. Each agent bumps from runtime v1 to v2 as a result.
################################################################################

# ── DynamoDB table for claim records ─────────────────────────────────────────

resource "aws_dynamodb_table" "claims" {
  count        = var.enable_agentcore ? 1 : 0
  name         = "${local.agentcore_name_prefix}-claims"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "claim_id"

  attribute {
    name = "claim_id"
    type = "S"
  }

  tags = var.tags
}

# ── Claims Reader Gateway (MCP) ─────────────────────────────────────────────
# Exposes get_claim_data and get_claim_photos tools to agents via MCP protocol.
# Backed by a Lambda that reads claim data from S3/DynamoDB.

resource "aws_iam_role" "claims_gateway" {
  count = var.enable_agentcore ? 1 : 0
  name  = "${local.agentcore_name_prefix}-claims-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "bedrock-agentcore.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "claims_gateway_invoke_lambda" {
  count = var.enable_agentcore ? 1 : 0
  name  = "${local.agentcore_name_prefix}-claims-gateway-invoke-lambda"
  role  = aws_iam_role.claims_gateway[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.claims_reader[0].arn
    }]
  })
}

resource "aws_bedrockagentcore_gateway" "claims_reader" {
  count           = var.enable_agentcore ? 1 : 0
  name            = "${local.agentcore_name_prefix}-claims-gateway"
  role_arn        = aws_iam_role.claims_gateway[0].arn
  protocol_type   = "MCP"
  authorizer_type = "AWS_IAM"
  exception_level = "DEBUG"
}

resource "aws_bedrockagentcore_gateway_target" "get_claim_data" {
  count              = var.enable_agentcore ? 1 : 0
  name               = "${local.agentcore_name_prefix}-get-claim-data"
  gateway_identifier = aws_bedrockagentcore_gateway.claims_reader[0].gateway_id

  credential_provider_configuration {
    gateway_iam_role {}
  }

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.claims_reader[0].arn

        tool_schema {
          inline_payload {
            name        = "get_claim_data"
            description = "Retrieve the full claim record including submission, extraction results, damage assessment, and fraud assessment."

            input_schema {
              type        = "object"
              description = "Claim data request"

              property {
                name        = "claim_id"
                type        = "string"
                description = "The claim identifier"
                required    = true
              }
            }

            output_schema {
              type        = "object"
              description = "Full claim record"
            }
          }
        }
      }
    }
  }
}

resource "aws_bedrockagentcore_gateway_target" "get_claim_photos" {
  count              = var.enable_agentcore ? 1 : 0
  name               = "${local.agentcore_name_prefix}-get-claim-photos"
  gateway_identifier = aws_bedrockagentcore_gateway.claims_reader[0].gateway_id

  credential_provider_configuration {
    gateway_iam_role {}
  }

  target_configuration {
    mcp {
      lambda {
        lambda_arn = aws_lambda_function.claims_reader[0].arn

        tool_schema {
          inline_payload {
            name        = "get_claim_photos"
            description = "List all photo documents for a claim, returning S3 paths."

            input_schema {
              type        = "object"
              description = "Claim photos request"

              property {
                name        = "claim_id"
                type        = "string"
                description = "The claim identifier"
                required    = true
              }
            }

            output_schema {
              type        = "array"
              description = "List of photo S3 paths"
            }
          }
        }
      }
    }
  }
}

# ── Claims Reader Lambda (gateway backend) ───────────────────────────────────

resource "aws_iam_role" "claims_reader_lambda" {
  count = var.enable_agentcore ? 1 : 0
  name  = "${local.agentcore_name_prefix}-claims-reader-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "claims_reader_lambda" {
  count = var.enable_agentcore ? 1 : 0
  name  = "${local.agentcore_name_prefix}-claims-reader-lambda"
  role  = aws_iam_role.claims_reader_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [module.s3_bucket_clean[0].s3_bucket_arn, "${module.s3_bucket_clean[0].s3_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query"]
        Resource = aws_dynamodb_table.claims[0].arn
      }
    ]
  })
}

data "archive_file" "claims_reader_lambda" {
  count       = var.enable_agentcore ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/build/claims_reader_lambda.zip"

  source {
    content  = <<-PYTHON
import json
import logging
import os

import boto3

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
CLAIMS_BUCKET = os.environ.get("CLAIMS_BUCKET", "")
CLAIMS_TABLE = os.environ.get("CLAIMS_TABLE", "")
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}
TOOL_NAME_DELIMITER = "___"


def _resolve_tool_name(context):
    """Extract the tool name from the AgentCore Gateway context.

    AgentCore Gateway sends the tool name in context.client_context.custom,
    formatted as target_name + '___' + tool_name. We strip the target prefix.
    """
    try:
        custom = context.client_context.custom
    except AttributeError:
        return ""
    raw = custom.get("bedrockAgentCoreToolName", "")
    if TOOL_NAME_DELIMITER in raw:
        return raw.split(TOOL_NAME_DELIMITER, 1)[1]
    return raw


def lambda_handler(event, context):
    tool_name = _resolve_tool_name(context)
    logger.info("Invoked tool=%s event=%s", tool_name, json.dumps(event))

    # AgentCore Gateway sends the input schema properties directly as the event dict.
    claim_id = event.get("claim_id", "") if isinstance(event, dict) else ""

    if tool_name == "get_claim_data":
        return get_claim_data(claim_id)
    if tool_name == "get_claim_photos":
        return get_claim_photos(claim_id)

    logger.error("Unknown tool name resolved from context: %r", tool_name)
    return {"error": f"Unknown tool: {tool_name}"}


def get_claim_data(claim_id):
    logger.info("get_claim_data claim_id=%s", claim_id)
    try:
        dynamodb = boto3.resource("dynamodb")
        table = dynamodb.Table(CLAIMS_TABLE)
        response = table.get_item(Key={"claim_id": claim_id})
        if "Item" in response:
            return json.loads(json.dumps(response["Item"], default=str))
    except Exception:
        logger.exception("DynamoDB get_item failed for %s — falling back to S3 listing", claim_id)

    # Fallback: list S3 objects under claim prefix
    prefix = f"{claim_id}/"
    resp = s3.list_objects_v2(Bucket=CLAIMS_BUCKET, Prefix=prefix)
    keys = [obj["Key"] for obj in resp.get("Contents", []) if not obj["Key"].endswith("/")]
    return {"claim_id": claim_id, "documents": keys}


def get_claim_photos(claim_id):
    logger.info("get_claim_photos claim_id=%s", claim_id)
    prefix = f"{claim_id}/"
    resp = s3.list_objects_v2(Bucket=CLAIMS_BUCKET, Prefix=prefix)
    photos = []
    for obj in resp.get("Contents", []):
        key = obj["Key"]
        ext = os.path.splitext(key)[1].lower()
        if ext in IMAGE_EXTENSIONS:
            photos.append(key)
    return photos
    PYTHON
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "claims_reader" {
  count         = var.enable_agentcore ? 1 : 0
  filename      = data.archive_file.claims_reader_lambda[0].output_path
  function_name = "${local.agentcore_name_prefix}-claims-reader"
  role          = aws_iam_role.claims_reader_lambda[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"
  timeout       = 30

  source_code_hash = data.archive_file.claims_reader_lambda[0].output_base64sha256

  environment {
    variables = {
      CLAIMS_BUCKET = module.s3_bucket_clean[0].s3_bucket_id
      CLAIMS_TABLE  = aws_dynamodb_table.claims[0].name
    }
  }

  tags = var.tags
}

# ── Claims Orchestrator (S3 event → 4-agent pipeline → DynamoDB) ─────────────

module "claims_orchestrator" {
  count  = var.enable_agentcore ? 1 : 0
  source = "./modules/claims-orchestrator"

  name_prefix        = local.agentcore_name_prefix
  source_dir         = "${path.module}/agent-source-code/claims-orchestrator"
  claims_bucket_name = module.s3_bucket_clean[0].s3_bucket_id
  claims_bucket_arn  = module.s3_bucket_clean[0].s3_bucket_arn
  claims_table_name  = aws_dynamodb_table.claims[0].name
  claims_table_arn   = aws_dynamodb_table.claims[0].arn

  document_extraction_agent_arn = module.document_extraction_agent[0].agent_runtime_arn
  damage_assessment_agent_arn   = module.damage_assessment_agent[0].agent_runtime_arn
  fraud_detection_agent_arn     = module.fraud_detection_agent[0].agent_runtime_arn
  classification_agent_arn      = module.classification_agent[0].agent_runtime_arn

  tags = var.tags
}

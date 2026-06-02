################################################################################
# AI Claims Orchestration
# Components: MCP Gateway + Claims Reader Lambda + DynamoDB + Orchestrator
#
# The AgentCore agent runtimes themselves are created in agentcore-agents.tf.
# This file wires them into the data plane:
#
#   - DynamoDB table for claim records
#   - MCP gateway + Lambda backend that gives 3 of the 4 agents access to
#     get_claim_data / get_claim_photos tools
#   - Orchestrator Lambda that watches the clean bucket for claim zips and
#     runs the agents through their pipeline stages
#
# When enable_agentcore = true, this file also adds the gateway wiring to the
# 3 gateway-using agents (damage_assessment, fraud_detection, classification):
# invoke-gateway IAM + AGENTCORE_GATEWAY_URL env var, in place. The
# data-bucket IAM and CLAIMS_BUCKET env var were already attached to all 4
# agents in malware-protection.tf (gated by enable_malware_protection, once
# module.s3_bucket_clean came online). document_extraction_agent is unchanged
# by this file — it reads S3 directly via boto3.
################################################################################

# ── DynamoDB table for claim records ─────────────────────────────────────────

resource "aws_dynamodb_table" "claims" {
  #checkov:skip=CKV_AWS_119: "Using AWS managed encryption is acceptable for this use case"
  count        = var.enable_agentcore ? 1 : 0
  name         = "${local.agentcore_name_prefix}-claims"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "claim_id"

  attribute {
    name = "claim_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
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

# ── Claims Reader Lambda (exposed through AgentCore gateway backend) ───────────────────────────────────

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
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "claims_reader_lambda" {
  count       = var.enable_agentcore ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/lambda-source-code/claims-reader"
  output_path = "${path.module}/build/claims_reader_lambda.zip"
}

resource "aws_lambda_function" "claims_reader" {
  #checkov:skip=CKV_AWS_50: "X-ray tracing is enabled"
  #checkov:skip=CKV_AWS_115: "Concurrent execution limit not required, AWS manages throttling"
  #checkov:skip=CKV_AWS_116: "DLQ not required for synchronous claims_reader Lambda invoked by MCP gateway"
  #checkov:skip=CKV_AWS_117: "Lambda function does not require VPC configuration for this use case"
  #checkov:skip=CKV_AWS_173: "Using AWS managed encryption is acceptable for this use case"
  #checkov:skip=CKV_AWS_272: "Code signing adds operational complexity without significant security benefit"
  count         = var.enable_agentcore ? 1 : 0
  filename      = data.archive_file.claims_reader_lambda[0].output_path
  function_name = "${local.agentcore_name_prefix}-claims-reader"
  role          = aws_iam_role.claims_reader_lambda[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"
  timeout       = 30

  source_code_hash = data.archive_file.claims_reader_lambda[0].output_base64sha256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      CLAIMS_BUCKET = module.s3_bucket_clean[0].s3_bucket_id
      CLAIMS_TABLE  = aws_dynamodb_table.claims[0].name
    }
  }

  tags = var.tags
}

# ── Claims Orchestrator (S3 event → 4-agent pipeline → DynamoDB) ─────────────

data "archive_file" "claims_orchestrator" {
  count       = var.enable_agentcore ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/lambda-source-code/claims-orchestrator"
  output_path = "${path.module}/build/claims_orchestrator.zip"
}

resource "aws_sqs_queue" "orchestrator_dlq" {
  count                     = var.enable_agentcore ? 1 : 0
  name                      = "${local.agentcore_name_prefix}-claims-orchestrator-dlq"
  message_retention_seconds = 1209600 # 14 days
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

resource "aws_lambda_function" "claims_orchestrator" {
  #checkov:skip=CKV_AWS_117: "Orchestrator only calls AWS service endpoints (S3, DynamoDB, Bedrock AgentCore). No private VPC resources to reach."
  #checkov:skip=CKV_AWS_173: "Environment variables contain only AWS resource identifiers. No secrets stored."
  #checkov:skip=CKV_AWS_272: "Code signing adds operational complexity without significant security benefit for this example."
  count                          = var.enable_agentcore ? 1 : 0
  filename                       = data.archive_file.claims_orchestrator[0].output_path
  function_name                  = "${local.agentcore_name_prefix}-claims-orchestrator"
  role                           = aws_iam_role.claims_orchestrator[0].arn
  handler                        = "index.handler"
  runtime                        = "python3.13"
  timeout                        = 900
  memory_size                    = 256
  source_code_hash               = data.archive_file.claims_orchestrator[0].output_base64sha256
  reserved_concurrent_executions = -1

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.orchestrator_dlq[0].arn
  }

  environment {
    variables = {
      CLAIMS_TABLE                  = aws_dynamodb_table.claims[0].name
      CLAIMS_BUCKET                 = module.s3_bucket_clean[0].s3_bucket_id
      DOCUMENT_EXTRACTION_AGENT_ARN = module.document_extraction_agent[0].agent_runtime_arn
      DAMAGE_ASSESSMENT_AGENT_ARN   = module.damage_assessment_agent[0].agent_runtime_arn
      FRAUD_DETECTION_AGENT_ARN     = module.fraud_detection_agent[0].agent_runtime_arn
      CLASSIFICATION_AGENT_ARN      = module.classification_agent[0].agent_runtime_arn
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "claims_orchestrator" {
  count = var.enable_agentcore ? 1 : 0
  name  = "${local.agentcore_name_prefix}-claims-orchestrator-role"

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

resource "aws_iam_role_policy" "claims_orchestrator" {
  count = var.enable_agentcore ? 1 : 0
  name  = "${local.agentcore_name_prefix}-claims-orchestrator-policy"
  role  = aws_iam_role.claims_orchestrator[0].id

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
        Action   = ["s3:GetObject", "s3:ListBucket", "s3:PutObject", "s3:DeleteObject"]
        Resource = [module.s3_bucket_clean[0].s3_bucket_arn, "${module.s3_bucket_clean[0].s3_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem", "dynamodb:Query"]
        Resource = [aws_dynamodb_table.claims[0].arn]
      },
      {
        Effect = "Allow"
        Action = ["bedrock-agentcore:InvokeAgentRuntime"]
        Resource = [
          module.document_extraction_agent[0].agent_runtime_arn, "${module.document_extraction_agent[0].agent_runtime_arn}/*",
          module.damage_assessment_agent[0].agent_runtime_arn, "${module.damage_assessment_agent[0].agent_runtime_arn}/*",
          module.fraud_detection_agent[0].agent_runtime_arn, "${module.fraud_detection_agent[0].agent_runtime_arn}/*",
          module.classification_agent[0].agent_runtime_arn, "${module.classification_agent[0].agent_runtime_arn}/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.orchestrator_dlq[0].arn]
      }
    ]
  })
}

# ── S3 EventBridge trigger ───────────────────────────────────────────────────

resource "aws_s3_bucket_notification" "claims" {
  count       = var.enable_agentcore ? 1 : 0
  bucket      = module.s3_bucket_clean[0].s3_bucket_id
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "claim_uploaded" {
  count       = var.enable_agentcore ? 1 : 0
  name        = "${local.agentcore_name_prefix}-claim-uploaded"
  description = "Trigger claims processing on file uploads under claim-* prefixes"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [module.s3_bucket_clean[0].s3_bucket_id] }
      object = { key = [{ suffix = ".zip" }] }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "orchestrator" {
  count     = var.enable_agentcore ? 1 : 0
  rule      = aws_cloudwatch_event_rule.claim_uploaded[0].name
  target_id = "claims-orchestrator"
  arn       = aws_lambda_function.claims_orchestrator[0].arn
}

resource "aws_lambda_permission" "eventbridge_orchestrator" {
  count         = var.enable_agentcore ? 1 : 0
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.claims_orchestrator[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.claim_uploaded[0].arn
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  function_name = "${var.name_prefix}-claims-orchestrator"
}

# ── DynamoDB ─────────────────────────────────────────────────────────────────
# Table is created externally and passed in to avoid circular dependencies
# with the gateway Lambda that also needs the table reference.

# ── Lambda ───────────────────────────────────────────────────────────────────

data "archive_file" "orchestrator" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/orchestrator.zip"
}

resource "aws_sqs_queue" "orchestrator_dlq" {
  name                      = "${local.function_name}-dlq"
  message_retention_seconds = 1209600 # 14 days (SQS max)
  sqs_managed_sse_enabled   = true

  tags = var.tags
}

resource "aws_lambda_function" "orchestrator" {
  #checkov:skip=CKV_AWS_117: "Orchestrator only calls AWS service endpoints (S3, DynamoDB, Bedrock AgentCore, CloudWatch). No private VPC resources to reach; a VPC config would require NAT gateway or interface endpoints with no security benefit for this example."
  #checkov:skip=CKV_AWS_173: "Environment variables contain only AWS resource identifiers (bucket/table names, agent runtime ARNs). No secrets or PII stored in env vars; AWS-managed encryption at rest is sufficient."
  #checkov:skip=CKV_AWS_272: "Lambda code is built from local source via data.archive_file for this example. Code-signing via AWS Signer would require a signing profile and pipeline outside the scope of this infrastructure example."
  filename                       = data.archive_file.orchestrator.output_path
  function_name                  = local.function_name
  role                           = aws_iam_role.orchestrator.arn
  handler                        = "index.handler"
  runtime                        = "python3.13"
  timeout                        = 900
  memory_size                    = 256
  source_code_hash               = data.archive_file.orchestrator.output_base64sha256
  reserved_concurrent_executions = -1

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.orchestrator_dlq.arn
  }

  environment {
    variables = {
      CLAIMS_TABLE                  = var.claims_table_name
      CLAIMS_BUCKET                 = var.claims_bucket_name
      DOCUMENT_EXTRACTION_AGENT_ARN = var.document_extraction_agent_arn
      DAMAGE_ASSESSMENT_AGENT_ARN   = var.damage_assessment_agent_arn
      FRAUD_DETECTION_AGENT_ARN     = var.fraud_detection_agent_arn
      CLASSIFICATION_AGENT_ARN      = var.classification_agent_arn
    }
  }

  tags = var.tags
}

# ── IAM ──────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "orchestrator" {
  name = "${local.function_name}-role"

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

resource "aws_iam_role_policy" "orchestrator" {
  name = "${local.function_name}-policy"
  role = aws_iam_role.orchestrator.id

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
        Resource = [var.claims_bucket_arn, "${var.claims_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem", "dynamodb:Query"]
        Resource = [var.claims_table_arn]
      },
      {
        Effect = "Allow"
        Action = ["bedrock-agentcore:InvokeAgentRuntime"]
        Resource = [
          var.document_extraction_agent_arn, "${var.document_extraction_agent_arn}/*",
          var.damage_assessment_agent_arn, "${var.damage_assessment_agent_arn}/*",
          var.fraud_detection_agent_arn, "${var.fraud_detection_agent_arn}/*",
          var.classification_agent_arn, "${var.classification_agent_arn}/*",
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
        Resource = [aws_sqs_queue.orchestrator_dlq.arn]
      }
    ]
  })
}

# ── S3 EventBridge trigger ───────────────────────────────────────────────────

resource "aws_s3_bucket_notification" "claims" {
  bucket      = var.claims_bucket_name
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "claim_uploaded" {
  name        = "${var.name_prefix}-claim-uploaded"
  description = "Trigger claims processing on file uploads under claim-* prefixes"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [var.claims_bucket_name] }
      object = { key = [{ suffix = ".zip" }] }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "orchestrator" {
  rule      = aws_cloudwatch_event_rule.claim_uploaded.name
  target_id = "claims-orchestrator"
  arn       = aws_lambda_function.orchestrator.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.claim_uploaded.arn
}

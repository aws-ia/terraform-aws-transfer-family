#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

######################################
# Random Resources
######################################

resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 1
}

######################################
# Data Sources
######################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get KMS key from existing secret if provided
data "aws_secretsmanager_secret" "existing" {
  count = var.existing_secret_arn != null && var.existing_secret_arn != "" ? 1 : 0
  arn   = var.existing_secret_arn
}

######################################
# Locals
######################################

locals {
  connector_name = "retrieve-${random_pet.name.id}"
  kms_key_arn = var.existing_secret_arn != null ? data.aws_secretsmanager_secret.existing[0].kms_key_id : aws_kms_key.transfer_family_key[0].arn
}

###################################################################
# KMS Key (only when not using existing secret)
###################################################################
resource "aws_kms_key" "transfer_family_key" {
  count = var.existing_secret_arn == null ? 1 : 0
  
  description             = "KMS key for encrypting S3 bucket, DynamoDB, CloudWatch logs and connector credentials"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use KMS"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      {
        Sid    = "Allow S3 to use KMS"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager to use KMS"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "transfer_family_key_alias" {
  count = var.existing_secret_arn == null ? 1 : 0
  
  name          = "alias/transfer-family-retrieve-key-${random_pet.name.id}"
  target_key_id = aws_kms_key.transfer_family_key[0].key_id
}

resource "aws_kms_key_policy" "transfer_family_key_policy" {
  count = var.existing_secret_arn == null ? 1 : 0
  
  key_id = aws_kms_key.transfer_family_key[0].id
  policy = aws_kms_key.transfer_family_key[0].policy
}

###################################################################
# SQS Dead Letter Queue
###################################################################
resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "lambda-dlq-${random_pet.name.id}"
  kms_master_key_id        = local.kms_key_arn
  kms_data_key_reuse_period_seconds = 300
}

###################################################################
# DynamoDB Table for tracking file transfers
###################################################################
resource "aws_dynamodb_table" "file_transfer_tracking" {
  count = var.enable_dynamodb_tracking ? 1 : 0

  name           = "${random_pet.name.id}-file-transfers"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "file_path"

  attribute {
    name = "file_path"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.kms_key_arn
  }

  tags = {
    Environment = "Demo"
    Project     = "SFTP File Transfer Tracking"
  }
}

###################################################################
# S3 Bucket for retrieved files
###################################################################
module "retrieve_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "${random_pet.name.id}-retrieve-bucket"

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    status     = false
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = local.kms_key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

###################################################################
# SFTP Connector
###################################################################
module "sftp_connector" {
  source = "../../modules/transfer-connectors"

  connector_name = local.connector_name
  url            = var.sftp_server_endpoint
  s3_bucket_arn  = module.retrieve_s3_bucket.s3_bucket_arn
  s3_bucket_name = module.retrieve_s3_bucket.s3_bucket_id

  # Use existing secret
  user_secret_id   = var.existing_secret_arn
  create_secret    = var.existing_secret_arn == null
  secret_name      = var.existing_secret_arn == null ? "sftp-credentials-${random_pet.name.id}" : null
  secret_kms_key_id = var.existing_secret_arn == null ? aws_kms_key.transfer_family_key[0].arn : null
  sftp_username    = var.sftp_username
  sftp_private_key = var.sftp_private_key
  trusted_host_keys = var.trusted_host_keys

  S3_kms_key_arn   = local.kms_key_arn
  secrets_manager_kms_key_arn = local.kms_key_arn
  security_policy_name = "TransferSFTPConnectorSecurityPolicy-2024-03"
  test_connector_post_deployment = var.test_connector_post_deployment

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector Retrieve Dynamic"
  }
}

###################################################################
# Lambda Code Signing
###################################################################
resource "aws_signer_signing_profile" "lambda_signing_profile" {
  platform_id = "AWSLambda-SHA384-ECDSA"
  name        = "lambdasigningprofile${replace(random_pet.name.id, "-", "")}"
}

resource "aws_lambda_code_signing_config" "lambda_code_signing" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.lambda_signing_profile.arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Warn"
  }

  description = "Code signing config for Lambda function"
}

###################################################################
# Lambda Function for Dynamic File Discovery
###################################################################
resource "aws_lambda_function" "file_discovery" {
  #checkov:skip=CKV_AWS_117: "Lambda function does not require VPC configuration for this use case"
  filename         = "index.zip"
  function_name    = "sftp-file-discovery-${random_pet.name.id}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  
  reserved_concurrent_executions = 10
  code_signing_config_arn = aws_lambda_code_signing_config.lambda_code_signing.arn

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  kms_key_arn = local.kms_key_arn

  environment {
    variables = {
      CONNECTOR_ID = module.sftp_connector.connector_id
      S3_BUCKET    = module.retrieve_s3_bucket.s3_bucket_id
      S3_PREFIX    = var.s3_prefix
      SOURCE_DIRECTORY = var.source_directory
      DYNAMODB_TABLE = var.enable_dynamodb_tracking ? aws_dynamodb_table.file_transfer_tracking[0].name : ""
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [data.archive_file.lambda_zip]
}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/index.py"
  output_path = "${path.module}/index.zip"
}

###################################################################
# EventBridge Scheduler for Lambda
###################################################################
resource "aws_scheduler_schedule" "lambda_trigger" {
  name = "sftp-lambda-trigger-${random_pet.name.id}"
  
  schedule_expression = var.eventbridge_schedule
  kms_key_arn = local.kms_key_arn
  
  flexible_time_window {
    mode = "OFF"
  }
  
  target {
    arn      = aws_lambda_function.file_discovery.arn
    role_arn = aws_iam_role.scheduler_role.arn
  }
}

###################################################################
# IAM Roles and Policies
###################################################################

# Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "lambda-sftp-discovery-role-${random_pet.name.id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-sftp-discovery-policy-${random_pet.name.id}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "transfer:StartFileTransfer",
          "transfer:DescribeConnector",
          "transfer:StartDirectoryListing",
          "transfer:DescribeExecution"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.lambda_dlq.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          module.retrieve_s3_bucket.s3_bucket_arn,
          "${module.retrieve_s3_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.kms_key_arn
      }
    ], var.enable_dynamodb_tracking ? [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.file_transfer_tracking[0].arn
      }
    ] : [])
  })
}

# EventBridge Scheduler role
resource "aws_iam_role" "scheduler_role" {
  name = "eventbridge-scheduler-role-${random_pet.name.id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

# EventBridge Scheduler policy
resource "aws_iam_role_policy" "scheduler_policy" {
  name = "eventbridge-scheduler-policy-${random_pet.name.id}"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.file_discovery.arn
      }
    ]
  })
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_discovery.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.lambda_trigger.arn
}

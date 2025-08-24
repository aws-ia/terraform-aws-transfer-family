#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

######################################
# Defaults and Locals
######################################

resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 1
}

locals {
  connector_name = "retrieve-${random_pet.name.id}"
  sftp_url       = startswith(var.sftp_server_endpoint, "sftp://") ? var.sftp_server_endpoint : "sftp://${var.sftp_server_endpoint}"
  
  # Validation: ensure credentials are provided when creating new secret
  validate_credentials = var.existing_secret_arn == "" && var.sftp_password == "" && var.sftp_private_key == "" ? tobool("Error: When existing_secret_arn is empty, either sftp_password or sftp_private_key must be provided") : true
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get KMS key from existing secret if provided
data "aws_secretsmanager_secret" "existing" {
  count = var.existing_secret_arn != null ? 1 : 0
  arn   = var.existing_secret_arn
}

###################################################################
# Create Secrets Manager secret for SFTP credentials (only when existing_secret_arn is not provided)
###################################################################
resource "aws_secretsmanager_secret" "sftp_credentials" {
  count       = var.existing_secret_arn != null ? 0 : 1
  name        = "sftp-credentials-${random_pet.name.id}"
  description = "SFTP credentials for connector"
  kms_key_id  = aws_kms_key.transfer_family_key.arn
}

resource "aws_secretsmanager_secret_version" "sftp_credentials" {
  count     = var.existing_secret_arn != null ? 0 : 1
  secret_id = aws_secretsmanager_secret.sftp_credentials[0].id
  secret_string = jsonencode({
    username   = var.sftp_username
    password   = var.sftp_password != "" ? var.sftp_password : null
    privateKey = var.sftp_private_key != "" ? var.sftp_private_key : null
  })
}

###################################################################
# DynamoDB table for file tracking
###################################################################
resource "aws_dynamodb_table" "file_paths" {
  name           = "sftp-file-paths-${random_pet.name.id}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "file_path"

  attribute {
    name = "file_path"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.transfer_family_key.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "SFTP File Paths"
    Environment = "Demo"
  }
}

###################################################################
# KMS Key for encryption
###################################################################
resource "aws_kms_key" "transfer_family_key" {
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
        Sid    = "Allow DynamoDB to use KMS"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
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
  name          = "alias/transfer-family-retrieve-key-${random_pet.name.id}"
  target_key_id = aws_kms_key.transfer_family_key.key_id
}

resource "aws_kms_key_policy" "transfer_family_key_policy" {
  key_id = aws_kms_key.transfer_family_key.id
  policy = aws_kms_key.transfer_family_key.policy
}

###################################################################
# S3 Bucket for retrieved files
###################################################################
module "retrieve_s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${random_pet.name.id}-retrieve-bucket"

  # S3 bucket-level Public Access Block configuration (by default now AWS has made this default as true for S3 bucket-level block public access)
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    status     = true
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.transfer_family_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

###################################################################
# SFTP Connector
###################################################################
module "sftp_connector" {
  count  = var.connector_id == null ? 1 : 0
  source = "../../modules/transfer-connectors"

  connector_name = local.connector_name
  url            = local.sftp_url
  secret_arn     = var.existing_secret_arn != null ? var.existing_secret_arn : aws_secretsmanager_secret.sftp_credentials[0].arn

  trusted_host_keys = var.trusted_host_keys

  enable_logging = true
  kms_key_arn    = aws_kms_key.transfer_family_key.arn

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector Retrieve"
  }
}

###################################################################
# Lambda Function to Process Directory and Initiate SFTP Retrieve
###################################################################
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-sftp-retrieve-role-${random_pet.name.id}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda-sftp-retrieve-policy-${random_pet.name.id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "transfer:StartFileTransfer",
          "transfer:StartDirectoryListing",
          "transfer:DescribeExecution"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ],
        Resource = aws_dynamodb_table.file_paths.arn
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        Resource = aws_kms_key.transfer_family_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/index.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "sftp_retrieve" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "sftp-retrieve-${random_pet.name.id}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      CONNECTOR_ID = var.connector_id != null ? var.connector_id : module.sftp_connector[0].connector_id
      S3_BUCKET_NAME = module.retrieve_s3_bucket.s3_bucket_id
      S3_DESTINATION_PREFIX = var.s3_prefix
      SOURCE_DIRECTORY = var.source_directory
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.file_paths.name
    }
  }
}

###################################################################
# EventBridge Rule for Lambda trigger
###################################################################
resource "aws_cloudwatch_event_rule" "retrieve_schedule" {
  name                = "sftp-retrieve-schedule-${random_pet.name.id}"
  description         = "Trigger SFTP retrieve Lambda function"
  schedule_expression = var.eventbridge_schedule
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.retrieve_schedule.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.sftp_retrieve.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sftp_retrieve.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.retrieve_schedule.arn
}

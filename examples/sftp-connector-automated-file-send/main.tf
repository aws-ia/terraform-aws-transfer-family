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

resource "random_id" "suffix" {
  byte_length = 4
}

######################################
# Data Sources
######################################

data "aws_caller_identity" "current" {}

locals {
  connector_name = "retrieve-${random_pet.name.id}"
  create_secret = var.existing_secret_arn == null
  kms_key_arn = local.create_secret ? aws_kms_key.transfer_family_key[0].arn : data.aws_kms_key.existing[0].arn
}

# Get KMS key from existing secret if provided
data "aws_secretsmanager_secret" "existing" {
  count = local.create_secret ? 0 : 1
  arn   = var.existing_secret_arn
}

# Get KMS key details from existing secret
data "aws_kms_key" "existing" {
  count  = local.create_secret ? 0 : 1
  key_id = data.aws_secretsmanager_secret.existing[0].kms_key_id
}

###################################################################
# SFTP Connector
###################################################################
module "sftp_connector" {
  source = "../../modules/transfer-connectors"

  connector_name              = local.connector_name
  url                         = var.sftp_server_endpoint
  access_role                 = aws_iam_role.connector_role.arn
  user_secret_id              = var.existing_secret_arn
  secret_name                 = local.create_secret ? "sftp-credentials-${random_pet.name.id}" : null
  sftp_username               = local.create_secret ? var.sftp_username : ""
  sftp_private_key            = local.create_secret ? var.sftp_private_key : ""
  secrets_manager_kms_key_arn = local.kms_key_arn
  security_policy_name        = "TransferSFTPConnectorSecurityPolicy-2024-03"
  
  trusted_host_keys = var.trusted_host_keys
  test_connector_post_deployment = var.test_connector_post_deployment

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector"
  }
}

#####################################################################################
# IAM Role and Policy for the SFTP Connector
#####################################################################################

resource "aws_iam_role" "connector_role" {
  name = "transfer-connector-role-${local.connector_name}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      }
    ]
  })
}

# This policy is based off the example from the official AWS documentation https://docs.aws.amazon.com/transfer/latest/userguide/create-sftp-connector-procedure.html
resource "aws_iam_policy" "connector_policy" {
  name        = "transfer-connector-policy-${local.connector_name}"
  description = "Policy for AWS Transfer Family SFTP connector"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid = "AllowListingOfUserFolder",
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = module.test_s3_bucket.s3_bucket_arn
      },
      {
        Sid = "HomeDirObjectAccess",
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObjectVersion",
          "s3:GetObjectACL",
          "s3:PutObjectACL"
        ]
        Resource = "${module.test_s3_bucket.s3_bucket_arn}/*"
      },
    ], local.create_secret ? [] : [{
      Sid = "GetConnectorSecretValue",
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = var.existing_secret_arn
    }], local.kms_key_arn != null ? [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      Resource = local.kms_key_arn
    }] : [])
  })
}

resource "aws_iam_role_policy_attachment" "connector_policy_attachment" {
  role       = aws_iam_role.connector_role.name
  policy_arn = aws_iam_policy.connector_policy.arn
}

###################################################################
# Create Test S3 bucket for file uploads (triggers SFTP transfer)
###################################################################
module "test_s3_bucket" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=179576ca9e3d524f09370ff643ea80a0f753cdd7"
  bucket                   = lower("${random_pet.name.id}-${random_id.suffix.hex}-test-upload-bucket")
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = local.kms_key_arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning = {
    enabled = false
  }
}

# Enable EventBridge notifications for the test upload bucket
resource "aws_s3_bucket_notification" "test_bucket_notification" {
  bucket      = module.test_s3_bucket.s3_bucket_id
  eventbridge = true
}

###################################################################
# KMS key and policies for Transfer Server
###################################################################

# KMS Key resource
resource "aws_kms_key" "transfer_family_key" {
  count = local.create_secret ? 1 : 0
  
  description             = "KMS key for encrypting S3 bucket and cloudwatch log group and the connector credentials"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Purpose = "Transfer Family Encryption"
  }
}

# KMS Key Alias
resource "aws_kms_alias" "transfer_family_key_alias" {
  count = local.create_secret ? 1 : 0
  
  name          = "alias/transfer-family-key-${random_pet.name.id}"
  target_key_id = aws_kms_key.transfer_family_key[0].id
}

# KMS Key Policy
resource "aws_kms_key_policy" "transfer_family_key_policy" {
  count = local.create_secret ? 1 : 0
  
  key_id = aws_kms_key.transfer_family_key[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable Limited Admin Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = local.kms_key_arn
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:Describe*"
        ]
        Resource = local.kms_key_arn
      },
      {
        Sid    = "Allow EventBridge to use KMS"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = local.kms_key_arn
      }
    ]
  })
}

###################################################################
# EventBridge Rule for S3 Object Created Events
###################################################################
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "s3-object-created-${random_pet.name.id}"
  description = "Capture S3 object created events from test upload bucket and trigger file transfer to SFTP server"

  event_pattern = jsonencode({
    source      = ["aws.s3"],
    detail-type = ["Object Created"],
    detail      = {
      bucket = {
        name = [module.test_s3_bucket.s3_bucket_id]
      }
    }
  })
}

###################################################################
# SQS Dead Letter Queue for Lambda
###################################################################
resource "aws_sqs_queue" "lambda_dlq" {
  name = "lambda-dlq-${random_pet.name.id}"
  
  kms_master_key_id = local.kms_key_arn
  
  tags = {
    Purpose = "Lambda Dead Letter Queue"
  }
}

###################################################################
# Lambda Function to Process S3 Events and Initiate SFTP Transfer
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
  name               = "lambda-sftp-transfer-role-${random_pet.name.id}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-sftp-transfer-policy-${random_pet.name.id}"
  description = "Policy for Lambda to initiate SFTP transfers"
  
  policy = jsonencode({
    Version = "2012-10-17",
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
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          module.test_s3_bucket.s3_bucket_arn,
          "${module.test_s3_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt"
        ],
        Resource = local.kms_key_arn
      },
      {
        Effect = "Allow",
        Action = [
          "transfer:StartFileTransfer",
          "transfer:DescribeExecution"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage"
        ],
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


###################################################################
# Lambda Code Signing Configuration
###################################################################
resource "aws_signer_signing_profile" "lambda_signing_profile" {
  platform_id = "AWSLambda-SHA384-ECDSA"
  name        = "lambdasigningprofile${replace(random_pet.name.id, "-", "")}${random_id.suffix.hex}"
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

resource "aws_lambda_function" "sftp_transfer" {
  #checkov:skip=CKV_AWS_117: "Lambda function does not require VPC configuration for this use case"
  function_name    = "s3-copy-${random_pet.name.id}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  timeout          = 60
  memory_size      = 256
  reserved_concurrent_executions = 10
  kms_key_arn      = local.kms_key_arn
  code_signing_config_arn = aws_lambda_code_signing_config.lambda_code_signing.arn
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      CONNECTOR_ID = module.sftp_connector.connector_id
    }
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source_file = "${path.module}/index.py"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.sftp_transfer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sftp_transfer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created.arn
}

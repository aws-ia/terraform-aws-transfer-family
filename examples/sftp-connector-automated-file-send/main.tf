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
  server_name = "transfer-server-${random_pet.name.id}"
  kms_key_arn = var.existing_secret_arn != null ? data.aws_secretsmanager_secret.existing[0].kms_key_id : aws_kms_key.transfer_family_key[0].arn
}

###################################################################
# SFTP Connector
###################################################################
module "sftp_connector" {
  source = "../../modules/transfer-connectors"

  connector_name = "sftp-connector-${random_pet.name.id}"
  url            = var.sftp_server_endpoint
  s3_bucket_arn  = module.test_s3_bucket.s3_bucket_arn
  s3_bucket_name = module.test_s3_bucket.s3_bucket_id

  # Use existing secret
  user_secret_id   = var.existing_secret_arn
  create_secret    = var.existing_secret_arn == null
  secret_name      = var.existing_secret_arn == null ? "sftp-credentials-${random_pet.name.id}" : null
  secret_kms_key_id = var.existing_secret_arn == null ? local.kms_key_arn : null
  sftp_username    = var.sftp_username
  sftp_password    = var.sftp_password
  sftp_private_key = var.sftp_private_key
  trusted_host_keys = var.trusted_host_keys

  S3_kms_key_arn   = local.kms_key_arn
  secrets_manager_kms_key_arn = local.kms_key_arn
  security_policy_name = "TransferSFTPConnectorSecurityPolicy-2024-03"
  test_connector_post_deployment = var.test_connector_post_deployment

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector"
  }
}



###################################################################
# Create Test S3 bucket for file uploads (triggers SFTP transfer)
###################################################################
module "test_s3_bucket" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=179576ca9e3d524f09370ff643ea80a0f753cdd7"
  bucket                   = lower("${random_pet.name.id}-test-upload-bucket")
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
  count = var.existing_secret_arn == null ? 1 : 0
  
  description             = "KMS key for encrypting S3 bucket and cloudwatch log group and the connector credentials"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Purpose = "Transfer Family Encryption"
  }
}

# KMS Key Alias
resource "aws_kms_alias" "transfer_family_key_alias" {
  count = var.existing_secret_arn == null ? 1 : 0
  
  name          = "alias/transfer-family-key-${random_pet.name.id}"
  target_key_id = aws_kms_key.transfer_family_key[0].key_id
}

# KMS Key Policy
resource "aws_kms_key_policy" "transfer_family_key_policy" {
  count = var.existing_secret_arn == null ? 1 : 0
  
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

resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "lambda-dlq-${random_pet.name.id}"
  kms_master_key_id        = local.kms_key_arn
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_lambda_function" "sftp_transfer" {
  function_name    = "s3-copy-${random_pet.name.id}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  timeout          = 60
  memory_size      = 256
  reserved_concurrent_executions = 10
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  code_signing_config_arn = aws_lambda_code_signing_config.lambda_code_signing.arn
  kms_key_arn = local.kms_key_arn

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

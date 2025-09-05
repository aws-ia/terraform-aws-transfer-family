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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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

  connector_name                  = local.connector_name
  url                             = var.sftp_server_endpoint
  access_role                     = aws_iam_role.connector_role.arn

  # Use existing secret or create new one
  user_secret_id                  = var.existing_secret_arn
  secret_name                     = local.create_secret ? "sftp-credentials-${random_pet.name.id}" : null
  sftp_username                   = var.sftp_username
  sftp_private_key                = var.sftp_private_key
  trusted_host_keys               = var.trusted_host_keys
  secrets_manager_kms_key_arn     = local.kms_key_arn
  security_policy_name            = "TransferSFTPConnectorSecurityPolicy-2024-03"
  test_connector_post_deployment  = var.test_connector_post_deployment

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector Retrieve"
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
        Resource = module.retrieve_s3_bucket.s3_bucket_arn
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
        Resource = "${module.retrieve_s3_bucket.s3_bucket_arn}/*"
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
# Use existing KMS Key from the secret
###################################################################

resource "aws_kms_key" "transfer_family_key" {
  count = local.create_secret ? 1 : 0
  
  description             = "KMS key for encrypting S3 bucket, CloudWatch logs and connector credentials"
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
  count = local.create_secret ? 1 : 0
  
  name          = "alias/transfer-family-retrieve-key-${random_pet.name.id}"
  target_key_id = aws_kms_key.transfer_family_key[0].key_id
}

resource "aws_kms_key_policy" "transfer_family_key_policy" {
  count = local.create_secret ? 1 : 0
  
  key_id = aws_kms_key.transfer_family_key[0].id
  policy = aws_kms_key.transfer_family_key[0].policy
}

###################################################################
# S3 Bucket for retrieved files
###################################################################
module "retrieve_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "${random_pet.name.id}-retrieve-bucket"

  # S3 bucket-level Public Access Block configuration (by default now AWS has made this default as true for S3 bucket-level block public access)
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
# EventBridge Scheduler for DynamoDB logging (only if DynamoDB is enabled)
###################################################################
resource "aws_scheduler_schedule" "dynamodb_logging" {
  count = var.enable_dynamodb_tracking ? 1 : 0

  name                          = "sftp-dynamodb-log-${random_pet.name.id}"
  schedule_expression           = var.eventbridge_schedule
  schedule_expression_timezone  = "UTC"
  state                         = "ENABLED"
  kms_key_arn                   = local.kms_key_arn

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:dynamodb:putItem"
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      TableName = aws_dynamodb_table.file_transfer_tracking[0].name
      Item = {
        batch_id = {
          S = "batch-${random_pet.name.id}"
        }
        connector_id = {
          S = module.sftp_connector.connector_id
        }
        files_uploaded = {
          S = join(",", var.file_paths_to_retrieve)
        }
        status = {
          S = "TRANSFER_STARTED"
        }
      }
    })
  }
}

###################################################################
# EventBridge Scheduler for direct Transfer Family integration
###################################################################
# SQS Dead Letter Queue for EventBridge Scheduler failures
resource "aws_sqs_queue" "dlq" {
  name = "sftp-scheduler-dlq-${random_pet.name.id}"
  
  kms_master_key_id = local.kms_key_arn
  
  tags = {
    Environment = "Demo"
    Project     = "SFTP Scheduler DLQ"
  }
}

resource "aws_scheduler_schedule" "sftp_retrieve_direct" {
  #checkov:skip=CKV_AWS_297: "KMS encryption not required for this demo scheduler"
  name = "sftp-retrieve-direct-${random_pet.name.id}"
  
  schedule_expression = var.eventbridge_schedule
  state               = "ENABLED"
  
  flexible_time_window {
    mode = "OFF"
  }
  
  target {
    arn      = "arn:aws:scheduler:::aws-sdk:transfer:startFileTransfer"
    role_arn = aws_iam_role.scheduler_role.arn
    
    input = jsonencode({
      ConnectorId         = module.sftp_connector.connector_id
      RetrieveFilePaths   = var.file_paths_to_retrieve
      LocalDirectoryPath  = "/${module.retrieve_s3_bucket.s3_bucket_id}/${trimsuffix(var.s3_prefix, "/")}"
    })
  }
}

# IAM role for EventBridge Scheduler
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

# DynamoDB table for tracking file transfer status
resource "aws_dynamodb_table" "file_transfer_tracking" {
  count = var.enable_dynamodb_tracking ? 1 : 0

  name           = "${random_pet.name.id}-file-transfers"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "batch_id"

  attribute {
    name = "batch_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = "Demo"
    Project     = "SFTP File Transfer Tracking"
  }
}

# IAM policy for DynamoDB access (only created if DynamoDB is enabled)
resource "aws_iam_policy" "dynamodb_policy" {
  count = var.enable_dynamodb_tracking ? 1 : 0

  name        = "transfer-dynamodb-policy-${random_pet.name.id}"
  description = "Policy for Transfer Family to access DynamoDB tracking table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
    ]
  })
}

# Attach DynamoDB policy to scheduler role (only if DynamoDB is enabled)
resource "aws_iam_role_policy_attachment" "scheduler_dynamodb_policy" {
  count = var.enable_dynamodb_tracking ? 1 : 0

  role       = aws_iam_role.scheduler_role.name
  policy_arn = aws_iam_policy.dynamodb_policy[0].arn
}

# IAM policy for EventBridge Scheduler
resource "aws_iam_role_policy" "scheduler_policy" {
  name = "eventbridge-scheduler-policy-${random_pet.name.id}"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "transfer:StartFileTransfer"
        ]
        Resource = module.sftp_connector.connector_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.dlq.arn
      }
    ], var.enable_dynamodb_tracking ? [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.file_transfer_tracking[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.kms_key_arn
      }
    ] : [])
  })
}

###################################################################
# EventBridge Event Listener Lambda
###################################################################

# EventBridge listener Lambda function
data "archive_file" "event_listener_zip" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  type        = "zip"
  source_file = "${path.module}/event_listener.py"
  output_path = "${path.module}/event_listener.zip"
}

resource "aws_lambda_function" "event_listener" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  #checkov:skip=CKV_AWS_272: "Lambda function does not require code signing for this use case"
  #checkov:skip=CKV_AWS_116: "Lambda function does not require DLQ for this use case"
  #checkov:skip=CKV_AWS_117: "Lambda function does not require VPC configuration for this use case"
  filename         = data.archive_file.event_listener_zip[0].output_path
  function_name    = "sftp-event-listener-${random_pet.name.id}"
  role            = aws_iam_role.event_listener_role[0].arn
  handler         = "event_listener.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  memory_size     = 256
  reserved_concurrent_executions = 10
  kms_key_arn     = local.kms_key_arn
  source_code_hash = data.archive_file.event_listener_zip[0].output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.file_transfer_tracking[0].name
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Environment = "Demo"
    Project     = "SFTP Event Listener"
  }
}

# IAM role for event listener Lambda
resource "aws_iam_role" "event_listener_role" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  name = "lambda-event-listener-role-${random_pet.name.id}"

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

# IAM policy for event listener Lambda
resource "aws_iam_role_policy" "event_listener_policy" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  name = "lambda-event-listener-policy-${random_pet.name.id}"
  role = aws_iam_role.event_listener_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
          "transfer:ListFileTransferResults"
        ]
        Resource = module.sftp_connector.connector_arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.file_transfer_tracking[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.kms_key_arn
      }
    ]
  })
}

###################################################################
# Status Checker Scheduler
###################################################################

# EventBridge Scheduler for status checking
resource "aws_scheduler_schedule" "status_checker" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  name = "transfer-status-checker-${random_pet.name.id}"
  kms_key_arn = local.kms_key_arn
  
  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(1 minute)"

  target {
    arn      = aws_lambda_function.event_listener[0].arn
    role_arn = aws_iam_role.status_checker_scheduler_role[0].arn
  }
}

# IAM role for status checker scheduler
resource "aws_iam_role" "status_checker_scheduler_role" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  name = "status-checker-scheduler-role-${random_pet.name.id}"

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

# IAM policy for status checker scheduler
resource "aws_iam_role_policy" "status_checker_scheduler_policy" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  name = "status-checker-scheduler-policy-${random_pet.name.id}"
  role = aws_iam_role.status_checker_scheduler_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.event_listener[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.kms_key_arn
      }
    ]
  })
}

# Lambda permission for status checker scheduler
resource "aws_lambda_permission" "allow_scheduler_status_checker" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  statement_id  = "AllowExecutionFromScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_listener[0].function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.status_checker[0].arn
}

# EventBridge rule for Transfer Family events
resource "aws_cloudwatch_event_rule" "transfer_events" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  name        = "transfer-family-events-${random_pet.name.id}"
  description = "Capture Transfer Family connector events"

  event_pattern = jsonencode({
    source      = ["aws.transfer"]
    detail-type = [
      "SFTP Connector File Retrieve Completed",
      "SFTP Connector File Retrieve Failed",
      "SFTP Connector File Retrieve Started"
    ]
  })

  tags = {
    Environment = "Demo"
    Project     = "SFTP Event Processing"
  }
}

# EventBridge target for the listener Lambda
resource "aws_cloudwatch_event_target" "event_listener_target" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.transfer_events[0].name
  target_id = "TransferEventListener"
  arn       = aws_lambda_function.event_listener[0].arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_event_listener" {
  count = var.enable_dynamodb_tracking ? 1 : 0
  
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_listener[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.transfer_events[0].arn
}

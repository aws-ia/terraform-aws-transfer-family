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
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get KMS key from existing secret if provided (only when not destroying)
data "aws_secretsmanager_secret" "existing" {
  count = var.existing_secret_arn != null && var.existing_secret_arn != "" ? 1 : 0
  arn   = var.existing_secret_arn
}



###################################################################
# KMS Key for encryption
###################################################################
resource "aws_kms_key" "transfer_family_key" {
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
    status     = false
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

  connector_name    = local.connector_name
  url              = var.sftp_server_endpoint
  s3_bucket_arn    = module.retrieve_s3_bucket.s3_bucket_arn
  s3_bucket_name   = module.retrieve_s3_bucket.s3_bucket_id
  
  # Use existing secret or create new one
  user_secret_id   = var.existing_secret_arn
  create_secret    = var.existing_secret_arn == null
  secret_name      = var.existing_secret_arn == null ? "sftp-credentials-${random_pet.name.id}" : null
  secret_kms_key_id = var.existing_secret_arn == null ? aws_kms_key.transfer_family_key.arn : null
  sftp_username    = var.sftp_username
  sftp_password    = var.sftp_password
  sftp_private_key = var.sftp_private_key

  trusted_host_keys = var.trusted_host_keys
  S3_kms_key_arn   = aws_kms_key.transfer_family_key.arn
  secrets_manager_kms_key_arn = var.existing_secret_arn != null ? null : aws_kms_key.transfer_family_key.arn

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector Retrieve"
  }
}



###################################################################
# EventBridge Scheduler for DynamoDB logging (only if DynamoDB is enabled)
###################################################################
resource "aws_scheduler_schedule" "dynamodb_logging" {
  count = var.enable_dynamodb_tracking ? 1 : 0

  name                         = "sftp-dynamodb-log-${random_pet.name.id}"
  schedule_expression          = var.eventbridge_schedule
  schedule_expression_timezone = "UTC"
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:dynamodb:putItem"
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      TableName = aws_dynamodb_table.file_transfer_tracking[0].name
      Item = {
        file_path = {
          S = "batch_transfer"
        }
        status = {
          S = "initiated"
        }
        file_count = {
          N = tostring(length(var.file_paths_to_retrieve))
        }
        file_paths = {
          S = join(",", var.file_paths_to_retrieve)
        }
        connector_id = {
          S = var.connector_id != null ? var.connector_id : module.sftp_connector[0].connector_id
        }
        s3_destination = {
          S = "/${module.retrieve_s3_bucket.s3_bucket_id}/${var.s3_prefix}"
        }
      }
    })
  }
}

###################################################################
# EventBridge Scheduler for direct Transfer Family integration
###################################################################
resource "aws_scheduler_schedule" "sftp_retrieve_direct" {
  name = "sftp-retrieve-direct-${random_pet.name.id}"
  
  schedule_expression = var.eventbridge_schedule
  
  flexible_time_window {
    mode = "OFF"
  }
  
  target {
    arn      = "arn:aws:scheduler:::aws-sdk:transfer:startFileTransfer"
    role_arn = aws_iam_role.scheduler_role.arn
    
    input = jsonencode({
      ConnectorId         = var.connector_id != null ? var.connector_id : module.sftp_connector[0].connector_id
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
  hash_key       = "file_path"

  attribute {
    name = "file_path"
    type = "S"
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
        Resource = "*"
      }
    ], var.enable_dynamodb_tracking ? [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.file_transfer_tracking[0].arn
      }
    ] : [])
  })
}

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
  server_name    = "transfer-server-${random_pet.name.id}"
  connector_name = "sftp-connector-${random_pet.name.id}"
  users          = var.users_file != null ? (fileexists(var.users_file) ? csvdecode(file(var.users_file)) : []) : [] # Read users from CSV
  
  # Determine connector ID for workflow
  workflow_connector_id = var.existing_connector_id != null ? var.existing_connector_id : module.sftp_connector_auto_discovery.connector_id
}

data "aws_caller_identity" "current" {}

###################################################################
# Transfer Server example usage (acts as the "external" SFTP server)
###################################################################
module "transfer_server" {
  source = "../.."
  
  domain                   = "S3"
  protocols                = ["SFTP"]
  endpoint_type            = "PUBLIC"
  server_name              = local.server_name
  dns_provider             = var.dns_provider
  custom_hostname          = var.custom_hostname
  route53_hosted_zone_name = var.route53_hosted_zone_name
  identity_provider        = "SERVICE_MANAGED"
  security_policy_name     = "TransferSecurityPolicy-2024-01"
  enable_logging           = true
  log_retention_days       = 30
  log_group_kms_key_id     = aws_kms_key.transfer_family_key.arn
  logging_role             = var.logging_role
  workflow_details         = var.workflow_details 
}

module "sftp_users" {
  source = "../../modules/transfer-users"
  users  = local.users
  create_test_user = true # Test user is for demo purposes

  server_id = module.transfer_server.server_id

  s3_bucket_name = module.sftp_server_bucket.s3_bucket_id
  s3_bucket_arn  = module.sftp_server_bucket.s3_bucket_arn

  kms_key_id = aws_kms_key.transfer_family_key.arn
}

###################################################################
# SFTP Connector Example Usage
###################################################################

# Example 1: Auto-discovery of host keys (recommended for development)
module "sftp_connector_auto_discovery" {
  source = "../../modules/transfer-connectors"

  connector_name  = "${local.connector_name}-auto"
  sftp_server_url = "sftp://${module.transfer_server.server_endpoint}"
  s3_bucket_arn   = module.file_send_source_bucket.s3_bucket_arn

  # SFTP Authentication - using the test user SSH private key
  sftp_username    = module.sftp_users.test_user_created ? module.sftp_users.test_user_details.username : var.sftp_username
  sftp_private_key = module.sftp_users.test_user_created ? module.sftp_users.test_user_details.private_key : null

  # Auto-discover host keys (default behavior)
  auto_discover_host_keys = true
  trusted_host_keys       = []

  # Optional configurations
  max_concurrent_connections = var.max_concurrent_connections
  security_policy_name       = var.security_policy_name

  # KMS encryption for secrets
  kms_key_arn           = aws_kms_key.transfer_family_key.arn
  enable_kms_encryption = true

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector Auto-Discovery"
    Example     = "auto-discovery"
  }

  depends_on = [module.sftp_users] # Ensure users are created first
}

# Example 2: Manual host key configuration (recommended for production)
module "sftp_connector_manual_keys" {
  count = length(var.trusted_host_keys) > 0 ? 1 : 0

  source = "../../modules/transfer-connectors"

  connector_name  = "${local.connector_name}-manual"
  sftp_server_url = "sftp://${module.transfer_server.server_endpoint}"
  s3_bucket_arn   = module.file_send_source_bucket.s3_bucket_arn

  # SFTP Authentication - using the test user SSH private key
  sftp_username    = module.sftp_users.test_user_created ? module.sftp_users.test_user_details.username : var.sftp_username
  sftp_private_key = module.sftp_users.test_user_created ? module.sftp_users.test_user_details.private_key : null

  # Manual host key configuration
  auto_discover_host_keys = false
  trusted_host_keys       = var.trusted_host_keys

  # Optional configurations
  max_concurrent_connections = var.max_concurrent_connections
  security_policy_name       = var.security_policy_name

  # Use existing IAM roles (optional)
  s3_access_role_arn = var.existing_s3_role_arn
  logging_role_arn   = var.existing_logging_role_arn

  # KMS encryption for secrets
  kms_key_arn           = aws_kms_key.transfer_family_key.arn
  enable_kms_encryption = true

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector Manual Keys"
    Example     = "manual-keys"
  }

  depends_on = [module.sftp_users] # Ensure users are created first
}

###################################################################
# S3 Buckets
###################################################################

# S3 bucket for Transfer Server storage
module "sftp_server_bucket" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v4.2.1"
  bucket                   = lower("${random_pet.name.id}-${module.transfer_server.server_id}-sftp-server")
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.transfer_family_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning = {
    enabled = false
  }

  tags = {
    Purpose = "SFTP Server Storage"
  }
}

# S3 bucket for File Send Source (monitored for automated file sending)
module "file_send_source_bucket" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v4.2.1"
  bucket                   = lower("${random_pet.name.id}-sftp-file-send-source")
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.transfer_family_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning = {
    enabled = true
  }



  tags = {
    Purpose = "SFTP File Send Source - Monitored for Automated Transfers"
  }
}

# S3 bucket notification configuration for EventBridge
resource "aws_s3_bucket_notification" "file_send_source_notification" {
  bucket      = module.file_send_source_bucket.s3_bucket_id
  eventbridge = true
}

###################################################################
# Automated File Send Workflow - EventBridge Integration
###################################################################

# EventBridge Rule for S3 Object Created Events in monitored prefix
resource "aws_cloudwatch_event_rule" "s3_file_send_trigger" {
  name        = "sftp-file-send-trigger-${random_pet.name.id}"
  description = "Trigger SFTP file transfer when files are created in monitored S3 prefix"
  state       = "ENABLED"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [module.file_send_source_bucket.s3_bucket_id]
      }
      object = {
        key = [{
          prefix = var.s3_monitoring_prefix
        }]
      }
    }
  })

  tags = {
    Purpose = "SFTP Automated File Send Workflow"
  }
}

# Lambda function to trigger Transfer Family file transfer
resource "aws_lambda_function" "start_file_transfer" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "start-sftp-file-transfer-${random_pet.name.id}"
  role            = aws_iam_role.lambda_transfer_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 60
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      CONNECTOR_ID           = local.workflow_connector_id
      REMOTE_DIRECTORY_PATH  = var.remote_directory_path
    }
  }

  tags = {
    Name = "start-sftp-file-transfer-${random_pet.name.id}"
  }
}

# Lambda function source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/start_file_transfer.zip"
  source {
    content = <<EOF
import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    try:
        # Initialize Transfer Family client
        transfer_client = boto3.client('transfer')
        
        # Extract S3 event details
        bucket = event['detail']['bucket']['name']
        key = event['detail']['object']['key']
        
        # Get environment variables
        connector_id = os.environ['CONNECTOR_ID']
        remote_directory_path = os.environ.get('REMOTE_DIRECTORY_PATH', '/')
        
        logger.info(f"Starting file transfer for s3://{bucket}/{key}")
        
        # Start file transfer
        response = transfer_client.start_file_transfer(
            ConnectorId=connector_id,
            SendFilePaths=[f"/{bucket}/{key}"],
            RemoteDirectoryPath=remote_directory_path
        )
        
        logger.info(f"File transfer started successfully: {response['TransferId']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File transfer started successfully',
                'transferId': response['TransferId']
            })
        }
        
    except Exception as e:
        logger.error(f"Error starting file transfer: {str(e)}")
        raise e
EOF
    filename = "index.py"
  }
}

# EventBridge Target - Lambda Function
resource "aws_cloudwatch_event_target" "start_file_transfer" {
  rule      = aws_cloudwatch_event_rule.s3_file_send_trigger.name
  target_id = "StartSFTPFileTransferLambda"
  arn       = aws_lambda_function.start_file_transfer.arn

  depends_on = [
    aws_cloudwatch_event_rule.s3_file_send_trigger
  ]
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_file_transfer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_file_send_trigger.arn
}

# IAM Role for Lambda to call Transfer Family Start-File-Transfer API
resource "aws_iam_role" "lambda_transfer_role" {
  name = "lambda-transfer-role-${random_pet.name.id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Purpose = "Lambda SFTP File Transfer Integration"
  }
}

resource "aws_iam_policy" "lambda_transfer_policy" {
  name        = "lambda-transfer-policy-${random_pet.name.id}"
  description = "Policy for Lambda to start SFTP file transfers"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "transfer:StartFileTransfer",
          "transfer:DescribeConnector"
        ],
        Resource = "arn:aws:transfer:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:connector/${local.workflow_connector_id}"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          module.file_send_source_bucket.s3_bucket_arn,
          "${module.file_send_source_bucket.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        Resource = aws_kms_key.transfer_family_key.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_transfer_policy_attachment" {
  role       = aws_iam_role.lambda_transfer_role.name
  policy_arn = aws_iam_policy.lambda_transfer_policy.arn
}

###################################################################
# KMS key for encryption
###################################################################

resource "aws_kms_key" "transfer_family_key" {
  description             = "KMS key for encrypting SFTP connector secrets and S3 buckets"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Purpose = "Transfer Family SFTP Connector Encryption"
  }
}

resource "aws_kms_alias" "transfer_family_key_alias" {
  name          = "alias/transfer-family-connector-key-${random_pet.name.id}"
  target_key_id = aws_kms_key.transfer_family_key.key_id
}

resource "aws_kms_key_policy" "transfer_family_key_policy" {
  key_id = aws_kms_key.transfer_family_key.id
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
        Resource = aws_kms_key.transfer_family_key.arn
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = aws_kms_key.transfer_family_key.arn
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/transfer/*"
          }
        }
      },
      {
        Sid    = "Allow Secrets Manager"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = aws_kms_key.transfer_family_key.arn
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = aws_kms_key.transfer_family_key.arn
      },
      {
        Sid    = "Allow Transfer Family Connector Roles"
        Effect = "Allow"
        Principal = {
          AWS = compact([
            module.sftp_connector_auto_discovery.s3_access_role_arn,
            length(module.sftp_connector_manual_keys) > 0 ? module.sftp_connector_manual_keys[0].s3_access_role_arn : null
          ])
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = aws_kms_key.transfer_family_key.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

###################################################################
# Data Sources
###################################################################
data "aws_region" "current" {}
# S3 bucket for CloudTrail logs
module "cloudtrail_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.1"

  bucket        = "cloudtrail-logs-${random_pet.name.id}"
  force_destroy = true

  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::cloudtrail-logs-${random_pet.name.id}"
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::cloudtrail-logs-${random_pet.name.id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudTrail for S3 Data Events
resource "aws_cloudtrail" "s3_data_events" {
  name                          = "s3-data-events-${random_pet.name.id}"
  include_global_service_events = false
  is_multi_region_trail        = false
  enable_logging               = true
  s3_bucket_name              = module.cloudtrail_bucket.s3_bucket_id

  event_selector {
    read_write_type           = "WriteOnly"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${module.file_send_source_bucket.s3_bucket_arn}/${var.s3_monitoring_prefix}"]
    }
  }

  depends_on = [module.cloudtrail_bucket]
}


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
data "aws_region" "current" {}

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
  s3_bucket_arn   = module.file_retrieve_destination_bucket.s3_bucket_arn

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
  s3_bucket_arn   = module.file_retrieve_destination_bucket.s3_bucket_arn

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

# S3 bucket for Transfer Server storage (acts as the remote SFTP server storage)
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

# S3 bucket for File Retrieve Destination (where retrieved files will be stored)
module "file_retrieve_destination_bucket" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v4.2.1"
  bucket                   = lower("${random_pet.name.id}-sftp-file-retrieve-destination")
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
    Purpose = "SFTP File Retrieve Destination"
  }
}

###################################################################
# DynamoDB Table for File Paths Management
###################################################################

resource "aws_dynamodb_table" "file_paths" {
  name           = "sftp-file-paths-${random_pet.name.id}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "file_path"

  attribute {
    name = "file_path"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name               = "status-index"
    hash_key           = "status"
    projection_type    = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.transfer_family_key.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Purpose = "SFTP File Paths Management"
  }
}

# Sample data for DynamoDB table
resource "aws_dynamodb_table_item" "sample_file_paths" {
  count      = length(var.sample_file_paths)
  table_name = aws_dynamodb_table.file_paths.name
  hash_key   = aws_dynamodb_table.file_paths.hash_key

  item = jsonencode({
    file_path = {
      S = var.sample_file_paths[count.index]
    }
    status = {
      S = "pending"
    }
    created_at = {
      S = timestamp()
    }
    local_directory_path = {
      S = "/${trimright(var.s3_destination_prefix, "/")}"
    }
  })
}

# Create sample files in the SFTP server bucket to match the DynamoDB file paths
resource "aws_s3_object" "sample_files" {
  count  = length(var.sample_file_paths)
  bucket = module.sftp_server_bucket.s3_bucket_id
  # Place files in test_user directory so they're accessible via SFTP
  key    = module.sftp_users.test_user_created ? "test_user${var.sample_file_paths[count.index]}" : var.sample_file_paths[count.index]
  
  content = "Sample file content for ${var.sample_file_paths[count.index]}\nCreated at: ${timestamp()}\nThis file will be retrieved by the automated workflow."
  
  server_side_encryption = "aws:kms"
  kms_key_id            = aws_kms_key.transfer_family_key.arn
  
  tags = {
    Purpose = "Sample file for automated retrieve workflow"
    FilePath = var.sample_file_paths[count.index]
  }
}

###################################################################
# Automated File Retrieve Workflow - EventBridge Schedule
###################################################################

# EventBridge Schedule for automated file retrieval
resource "aws_scheduler_schedule" "file_retrieve_schedule" {
  name       = "sftp-file-retrieve-schedule-${random_pet.name.id}"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.eventbridge_schedule_expression

  target {
    arn      = aws_lambda_function.retrieve_files.arn
    role_arn = aws_iam_role.eventbridge_scheduler_role.arn

    input = jsonencode({
      connector_id           = local.workflow_connector_id
      dynamodb_table_name    = aws_dynamodb_table.file_paths.name
      s3_destination_prefix  = var.s3_destination_prefix
    })
  }

  state = var.enable_automated_schedule ? "ENABLED" : "DISABLED"
}

# Lambda function to retrieve files from SFTP server
resource "aws_lambda_function" "retrieve_files" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "retrieve-sftp-files-${random_pet.name.id}"
  role            = aws_iam_role.lambda_transfer_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 300
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      CONNECTOR_ID            = local.workflow_connector_id
      DYNAMODB_TABLE_NAME     = aws_dynamodb_table.file_paths.name
      S3_DESTINATION_PREFIX   = var.s3_destination_prefix
      S3_DESTINATION_BUCKET   = module.destination_bucket.s3_bucket_id
    }
  }

  tags = {
    Name = "retrieve-sftp-files-${random_pet.name.id}"
  }
}

# Lambda function source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/retrieve_files.zip"
  source {
    content = <<EOF
import json
import boto3
import os
import logging
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    try:
        # Initialize AWS clients
        transfer_client = boto3.client('transfer')
        dynamodb = boto3.resource('dynamodb')
        
        # Get environment variables
        connector_id = os.environ['CONNECTOR_ID']
        table_name = os.environ['DYNAMODB_TABLE_NAME']
        s3_destination_prefix = os.environ.get('S3_DESTINATION_PREFIX', 'retrieved/')
        
        # Get DynamoDB table
        table = dynamodb.Table(table_name)
        
        logger.info(f"Starting file retrieval process for connector: {connector_id}")
        
        # Query for pending files
        response = table.query(
            IndexName='status-index',
            KeyConditionExpression='#status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':status': 'pending'}
        )
        
        pending_files = response.get('Items', [])
        
        if not pending_files:
            logger.info("No pending files found for retrieval")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No pending files found for retrieval',
                    'processed_files': 0
                })
            }
        
        # Extract file paths for retrieval
        retrieve_file_paths = [item['file_path'] for item in pending_files]
        
        logger.info(f"Found {len(retrieve_file_paths)} files to retrieve: {retrieve_file_paths}")
        
        # Start file transfer using retrieve operation
        transfer_response = transfer_client.start_file_transfer(
            ConnectorId=connector_id,
            RetrieveFilePaths=retrieve_file_paths,
            LocalDirectoryPath=s3_destination_prefix
        )
        
        transfer_id = transfer_response['TransferId']
        logger.info(f"File retrieval started successfully: {transfer_id}")
        
        # Update status of processed files to 'in_progress'
        for file_path in retrieve_file_paths:
            try:
                table.update_item(
                    Key={'file_path': file_path},
                    UpdateExpression='SET #status = :status, transfer_id = :transfer_id, updated_at = :updated_at',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={
                        ':status': 'in_progress',
                        ':transfer_id': transfer_id,
                        ':updated_at': context.aws_request_id
                    }
                )
            except ClientError as e:
                logger.error(f"Error updating status for {file_path}: {str(e)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File retrieval started successfully',
                'transferId': transfer_id,
                'processed_files': len(retrieve_file_paths),
                'file_paths': retrieve_file_paths
            })
        }
        
    except Exception as e:
        logger.error(f"Error during file retrieval: {str(e)}")
        raise e
EOF
    filename = "index.py"
  }
}

# Lambda permission for EventBridge Scheduler
resource "aws_lambda_permission" "allow_eventbridge_scheduler" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.retrieve_files.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.file_retrieve_schedule.arn
}

###################################################################
# IAM Roles and Policies
###################################################################

# IAM Role for Lambda to call Transfer Family and DynamoDB
resource "aws_iam_role" "lambda_transfer_role" {
  name = "lambda-transfer-retrieve-role-${random_pet.name.id}"

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
    Purpose = "Lambda SFTP File Retrieve Integration"
  }
}

resource "aws_iam_policy" "lambda_transfer_policy" {
  name        = "lambda-transfer-retrieve-policy-${random_pet.name.id}"
  description = "Policy for Lambda to retrieve SFTP files and manage DynamoDB"

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
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ],
        Resource = [
          aws_dynamodb_table.file_paths.arn,
          "${aws_dynamodb_table.file_paths.arn}/index/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          module.file_retrieve_destination_bucket.s3_bucket_arn,
          "${module.file_retrieve_destination_bucket.s3_bucket_arn}/*"
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

# IAM Role for EventBridge Scheduler
resource "aws_iam_role" "eventbridge_scheduler_role" {
  name = "eventbridge-scheduler-role-${random_pet.name.id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "scheduler.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Purpose = "EventBridge Scheduler for SFTP File Retrieve"
  }
}

resource "aws_iam_policy" "eventbridge_scheduler_policy" {
  name        = "eventbridge-scheduler-policy-${random_pet.name.id}"
  description = "Policy for EventBridge Scheduler to invoke Lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = aws_lambda_function.retrieve_files.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_scheduler_policy_attachment" {
  role       = aws_iam_role.eventbridge_scheduler_role.name
  policy_arn = aws_iam_policy.eventbridge_scheduler_policy.arn
}

###################################################################
# KMS key for encryption
###################################################################

resource "aws_kms_key" "transfer_family_key" {
  description             = "KMS key for encrypting SFTP connector secrets, S3 buckets, and DynamoDB"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Purpose = "Transfer Family SFTP Connector Encryption"
  }
}

resource "aws_kms_alias" "transfer_family_key_alias" {
  name          = "alias/transfer-family-connector-retrieve-key-${random_pet.name.id}"
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
          Service = "logs.${data.aws_region.current.id}.amazonaws.com"
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
        Sid    = "Allow DynamoDB Service"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = aws_kms_key.transfer_family_key.arn
      }
    ]
  })
}

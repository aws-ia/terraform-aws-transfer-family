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
  secret_string = jsonencode(
    var.sftp_private_key != "" ? {
      username = var.sftp_username
      pk       = var.sftp_private_key
    } : {
      username = var.sftp_username
      password = var.sftp_password
    }
  )
}

###################################################################
# Create SFTP Connector (if connector_id not provided)
###################################################################
module "sftp_connector" {
  count  = var.connector_id == null ? 1 : 0
  source = "../../modules/transfer-connectors"

  connector_name              = local.connector_name
  url                         = local.sftp_url
  s3_bucket_arn               = module.retrieve_s3_bucket.s3_bucket_arn
  s3_bucket_name              = module.retrieve_s3_bucket.s3_bucket_id
  user_secret_id              = var.existing_secret_arn != null ? var.existing_secret_arn : aws_secretsmanager_secret.sftp_credentials[0].arn
  secrets_manager_kms_key_arn = var.existing_secret_arn != null ? data.aws_secretsmanager_secret.existing[0].kms_key_id : aws_kms_key.transfer_family_key.arn
  S3_kms_key_arn              = aws_kms_key.transfer_family_key.arn
  security_policy_name        = "TransferSFTPConnectorSecurityPolicy-2024-03"
  
  trusted_host_keys = var.trusted_host_keys

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector Retrieve"
  }
}

###################################################################
# Create S3 bucket for retrieved files
###################################################################
module "retrieve_s3_bucket" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v5.0.0"
  bucket                   = lower("${random_pet.name.id}-retrieve-bucket")
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
}

###################################################################
# DynamoDB table for file paths
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

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector Retrieve"
  }
}

# Populate DynamoDB with sample file paths
resource "aws_dynamodb_table_item" "sample_files" {
  count      = length(var.file_paths_to_retrieve)
  table_name = aws_dynamodb_table.file_paths.name
  hash_key   = aws_dynamodb_table.file_paths.hash_key

  item = jsonencode({
    file_path = {
      S = var.file_paths_to_retrieve[count.index]
    }
    status = {
      S = "pending"
    }
  })
}

###################################################################
# KMS key and policies
###################################################################
resource "aws_kms_key" "transfer_family_key" {
  description             = "KMS key for encrypting S3 bucket, DynamoDB, CloudWatch logs and connector credentials"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Purpose = "Transfer Family Encryption"
  }
}

resource "aws_kms_alias" "transfer_family_key_alias" {
  name          = "alias/transfer-family-retrieve-key-${random_pet.name.id}"
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
        Resource = aws_kms_key.transfer_family_key.arn
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
        Resource = aws_kms_key.transfer_family_key.arn
      },
      {
        Sid    = "Allow DynamoDB to use KMS"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:Describe*"
        ]
        Resource = aws_kms_key.transfer_family_key.arn
      }
    ]
  })
}

###################################################################
# Lambda Function to Process DynamoDB and Initiate SFTP Retrieve
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
  name        = "lambda-sftp-retrieve-policy-${random_pet.name.id}"
  description = "Policy for Lambda to initiate SFTP file retrieval"
  
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
      },
      {
        Effect = "Allow",
        Action = [
          "transfer:StartFileTransfer"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "sftp_retrieve" {
  function_name    = "sftp-retrieve-${random_pet.name.id}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  timeout          = 300
  memory_size      = 256
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      CONNECTOR_ID = var.connector_id != null ? var.connector_id : module.sftp_connector[0].connector_id
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.file_paths.name
      S3_BUCKET_NAME = module.retrieve_s3_bucket.s3_bucket_id
      S3_DESTINATION_PREFIX = var.s3_prefix
    }
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  
  source {
    content  = <<EOF
import boto3
import os
import json
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
        s3_destination_prefix = os.environ.get('S3_DESTINATION_PREFIX', 'retrieved/').rstrip('/')
        # Ensure path starts with / for AWS Transfer Family
        if not s3_destination_prefix.startswith('/'):
            s3_destination_prefix = '/' + s3_destination_prefix
        
        # Get DynamoDB table
        table = dynamodb.Table(table_name)
        
        logger.info(f"Starting file retrieval process for connector: {connector_id}")
        
        # Scan for pending files (since we don't have GSI)
        logger.info(f"Scanning table {table_name} for pending files")
        response = table.scan(
            FilterExpression='#status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':status': 'pending'}
        )
        
        logger.info(f"DynamoDB scan response: {response}")
        pending_files = response.get('Items', [])
        logger.info(f"Pending files found: {len(pending_files)}")
        
        if not pending_files:
            # Check for in_progress files and their transfer status
            all_response = table.scan()
            all_items = all_response.get('Items', [])
            logger.info(f"All items in table: {all_items}")
            
            # Reset all in_progress items to pending for retry
            for item in all_items:
                if item.get('status') == 'in_progress':
                    table.update_item(
                        Key={'file_path': item['file_path']},
                        UpdateExpression='SET #status = :status',
                        ExpressionAttributeNames={'#status': 'status'},
                        ExpressionAttributeValues={':status': 'pending'}
                    )
                    logger.info(f"Reset {item['file_path']} to pending status")
            
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
        logger.info(f"Using LocalDirectoryPath: {s3_destination_prefix}")
        
        # Start file transfer using retrieve operation
        transfer_response = transfer_client.start_file_transfer(
            ConnectorId=connector_id,
            RetrieveFilePaths=retrieve_file_paths,
            LocalDirectoryPath=s3_destination_prefix
        )
        
        transfer_id = transfer_response['TransferId']
        logger.info(f"File retrieval started successfully: {transfer_id}")
        
        logger.info(f"Transfer started with ID: {transfer_id}")
        
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

###################################################################
# EventBridge Schedule for Automated Retrieval
###################################################################
resource "aws_cloudwatch_event_rule" "retrieve_schedule" {
  name                = "sftp-retrieve-schedule-${random_pet.name.id}"
  description         = "Schedule for automated SFTP file retrieval"
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

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
  server_name = "transfer-server-${random_pet.name.id}"
}

data "aws_caller_identity" "current" {}

###################################################################
# Transfer Server example usage
###################################################################
module "transfer_server" {
  source = "../.."
  
  domain                   = "S3"
  protocols                = ["SFTP"]
  endpoint_type            = "PUBLIC"
  server_name              = local.server_name
  identity_provider        = "SERVICE_MANAGED"
  security_policy_name     = "TransferSecurityPolicy-2024-01"
  enable_logging           = true
  log_retention_days       = 30
  log_group_kms_key_id     = aws_kms_key.transfer_family_key.arn
}

###################################################################
# Create SFTP Connector
###################################################################
module "sftp_connector" {
  source = "../../modules/transfer-connectors"

  connector_name        = "sftp-connector-${random_pet.name.id}"
  sftp_server_url       = var.sftp_server_url
  s3_bucket_arn         = module.test_s3_bucket.s3_bucket_arn
  s3_bucket_name        = module.test_s3_bucket.s3_bucket_id
  user_secret_id        = local.secret_arn
  kms_key_arn           = aws_kms_key.transfer_family_key.arn
  aws_region            = var.aws_region
  trust_all_certificates = var.trust_all_certificates
  security_policy_name  = "TransferSFTPConnectorSecurityPolicy-2024-03"
  trusted_host_keys     = var.trusted_host_keys

  tags = {
    Environment = "Demo"
    Project     = "SFTP Connector"
  }
}

###################################################################
# Create S3 bucket for Transfer Server
###################################################################
module "s3_bucket" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v5.0.0"
  bucket                   = lower("${random_pet.name.id}-${module.transfer_server.server_id}-s3-sftp")
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
# Create Test S3 bucket for file uploads (triggers SFTP transfer)
###################################################################
module "test_s3_bucket" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v5.0.0"
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
# KMS key and policies for Transfer Server
###################################################################

# KMS Key resource
resource "aws_kms_key" "transfer_family_key" {
  description             = "KMS key for encrypting S3 bucket and cloudwatch log group"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Purpose = "Transfer Family Encryption"
  }
}

# KMS Key Alias
resource "aws_kms_alias" "transfer_family_key_alias" {
  name          = "alias/transfer-family-key-${random_pet.name.id}"
  target_key_id = aws_kms_key.transfer_family_key.key_id
}

# KMS Key Policy
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
      }
    ]
  })
}

###################################################################
# SFTP credentials in Secrets Manager (use existing or create new)
###################################################################
locals {
  use_existing_secret = var.existing_secret_arn != ""
  secret_arn = local.use_existing_secret ? var.existing_secret_arn : aws_secretsmanager_secret.sftp_credentials[0].arn
}

# Use existing secret if provided
data "aws_secretsmanager_secret" "existing_sftp_credentials" {
  count = local.use_existing_secret ? 1 : 0
  arn   = var.existing_secret_arn
}

# Create new secret if no existing secret provided
resource "aws_secretsmanager_secret" "sftp_credentials" {
  count       = local.use_existing_secret ? 0 : 1
  name        = "sftp-credentials-${random_pet.name.id}"
  description = "SFTP credentials for the connector"
  kms_key_id  = aws_kms_key.transfer_family_key.arn
}

resource "aws_secretsmanager_secret_version" "sftp_credentials" {
  count         = local.use_existing_secret ? 0 : 1
  secret_id     = aws_secretsmanager_secret.sftp_credentials[0].id
  secret_string = jsonencode({
    username   = var.sftp_username
    password   = var.sftp_password != "" ? var.sftp_password : null
    privateKey = var.sftp_private_key != "" ? var.sftp_private_key : null
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
          "transfer:StartFileTransfer",
          "transfer:DescribeConnector",
          "transfer:ListFileTransferResults"
        ],
        Resource = module.sftp_connector.connector_arn
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt"
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

resource "aws_lambda_function" "sftp_transfer" {
  function_name    = "sftp-transfer-${random_pet.name.id}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  timeout          = 60
  memory_size      = 256
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      CONNECTOR_ID = module.sftp_connector.connector_id,
      REMOTE_PATH  = var.sftp_remote_path
    }
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  
  source {
    content  = <<EOF
const { TransferClient, StartFileTransferCommand, ListFileTransferResultsCommand } = require('@aws-sdk/client-transfer');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');

const transfer = new TransferClient();
const secrets = new SecretsManagerClient();

exports.handler = async (event) => {
  console.log('=== SFTP TRANSFER LAMBDA START ===');
  console.log('Received event:', JSON.stringify(event, null, 2));
  
  try {
    const bucket = event.detail.bucket.name;
    const key = event.detail.object.key;
    
    console.log(`Processing file: s3://$${bucket}/$${key}`);
    console.log(`Connector ID: $${process.env.CONNECTOR_ID}`);
    console.log(`Remote Path: $${process.env.REMOTE_PATH}`);
    
    // Only process files from the test upload bucket
    if (bucket !== 'aws-ia-eel-test-upload-bucket') {
      console.log(`SKIPPING: File from bucket: $${bucket} (not test upload bucket)`);
      return {
        statusCode: 200,
        body: JSON.stringify({
          message: 'File ignored - not from test upload bucket'
        })
      };
    }
    
    // Extract just the filename for the remote path
    const filename = key.split('/').pop();
    const remotePath = process.env.REMOTE_PATH ? `$${process.env.REMOTE_PATH}/$${filename}` : `/$${filename}`;
    
    // The local path should be the S3 key from the source bucket
    const localPath = key.startsWith('/') ? key : `/$${key}`;
    
    console.log(`Local path: $${localPath}`);
    console.log(`Remote path: $${remotePath}`);
    console.log(`Filename: $${filename}`);
    
    // Start file transfer using the connector
    const params = {
      ConnectorId: process.env.CONNECTOR_ID,
      SendFilePaths: [
        `$${localPath}:$${remotePath}`
      ]
    };
    
    console.log('=== STARTING FILE TRANSFER ===');
    console.log('Transfer params:', JSON.stringify(params, null, 2));
    
    const command = new StartFileTransferCommand(params);
    const result = await transfer.send(command);
    
    console.log('=== TRANSFER INITIATED SUCCESSFULLY ===');
    console.log('Transfer result:', JSON.stringify(result, null, 2));
    console.log(`Transfer ID: $${result.TransferId}`);
    
    // Wait a moment and check transfer status
    console.log('=== CHECKING TRANSFER STATUS ===');
    await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
    
    try {
      const statusCommand = new ListFileTransferResultsCommand({
        ConnectorId: process.env.CONNECTOR_ID,
        TransferId: result.TransferId
      });
      const statusResult = await transfer.send(statusCommand);
      console.log('Transfer status:', JSON.stringify(statusResult, null, 2));
    } catch (statusError) {
      console.log('Could not get transfer status (this is normal for new transfers):', statusError.message);
    }
    
    console.log('=== LAMBDA EXECUTION COMPLETE ===');
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'File transfer initiated successfully',
        transferId: result.TransferId,
        localPath: localPath,
        remotePath: remotePath,
        filename: filename
      })
    };
  } catch (error) {
    console.error('=== ERROR OCCURRED ===');
    console.error('Error processing file:', error);
    console.error('Error name:', error.name);
    console.error('Error message:', error.message);
    console.error('Error stack:', error.stack);
    console.error('Full error details:', JSON.stringify(error, null, 2));
    throw error;
  }
};
EOF
    filename = "index.js"
  }
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

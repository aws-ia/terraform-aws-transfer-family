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
  sftp_server_url       = "sftp://${module.transfer_server.server_endpoint}"
  s3_bucket_arn         = module.s3_bucket.s3_bucket_arn
  s3_bucket_name        = module.s3_bucket.s3_bucket_id
  user_secret_id        = aws_secretsmanager_secret.sftp_credentials.arn
  kms_key_arn           = aws_kms_key.transfer_family_key.arn
  aws_region            = var.aws_region
  trust_all_certificates = var.trust_all_certificates
  security_policy_name  = "TransferSecurityPolicy-2024-01"

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
# Create SFTP credentials in Secrets Manager
###################################################################
resource "aws_secretsmanager_secret" "sftp_credentials" {
  name        = "sftp-credentials-${random_pet.name.id}"
  description = "SFTP credentials for the connector"
  kms_key_id  = aws_kms_key.transfer_family_key.arn
}

resource "aws_secretsmanager_secret_version" "sftp_credentials" {
  secret_id     = aws_secretsmanager_secret.sftp_credentials.id
  secret_string = jsonencode({
    username = var.sftp_username
    password = var.sftp_password
    privateKey = var.sftp_private_key
  })
}

###################################################################
# IAM Role for EventBridge to call Transfer Family API
###################################################################
resource "aws_iam_role" "eventbridge_transfer_role" {
  name = "eventbridge-transfer-role-${random_pet.name.id}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "eventbridge_transfer_policy" {
  name        = "eventbridge-transfer-policy-${random_pet.name.id}"
  description = "Policy for EventBridge to initiate SFTP transfers"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "transfer:StartFileTransfer",
          "transfer:DescribeConnector"
        ],
        Resource = module.sftp_connector.connector_arn
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          module.s3_bucket.s3_bucket_arn,
          "${module.s3_bucket.s3_bucket_arn}/*"
        ]
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

resource "aws_iam_role_policy_attachment" "eventbridge_transfer_policy_attachment" {
  role       = aws_iam_role.eventbridge_transfer_role.name
  policy_arn = aws_iam_policy.eventbridge_transfer_policy.arn
}

###################################################################
# EventBridge Rule for S3 Object Created Events
###################################################################
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "s3-object-created-${random_pet.name.id}"
  description = "Capture S3 object created events and trigger file transfer to SFTP server"

  event_pattern = jsonencode({
    source      = ["aws.s3"],
    detail-type = ["Object Created"],
    detail      = {
      bucket = {
        name = [module.s3_bucket.s3_bucket_id]
      }
    }
  })
}

###################################################################
# EventBridge Target to directly call Transfer Family API
###################################################################
resource "aws_cloudwatch_event_target" "transfer_api_target" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "TransferFileToSFTP"
  arn       = "arn:aws:transfer:${var.aws_region}:${data.aws_caller_identity.current.account_id}:connector/${module.sftp_connector.connector_id}"
  role_arn  = aws_iam_role.eventbridge_transfer_role.arn
  
  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name",
      key    = "$.detail.object.key"
    }
    
    input_template = <<EOF
{
  "ConnectorId": "${module.sftp_connector.connector_id}",
  "LocalFilePath": <key>,
  "RemotePath": "${var.sftp_remote_path}/<key>"
}
EOF
  }
}

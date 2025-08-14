#####################################################################################
# AWS Transfer Family SFTP Connector Module
# This module creates an AWS Transfer Family SFTP connector to connect an S3 bucket to an SFTP server
#####################################################################################

######################################
# Defaults and Locals
######################################

resource "random_id" "connector_id" {
  count       = local.should_scan ? 1 : 0
  byte_length = 8
} 

data "aws_caller_identity" "current" {}

# Find existing secrets for AWS Transfer Family servers by description
data "aws_secretsmanager_secrets" "transfer_secrets" {
  count = local.is_aws_transfer_server ? 1 : 0
  
  filter {
    name   = "description"
    values = ["SFTP credentials for the test user"]
  }
}

data "aws_secretsmanager_secret" "transfer_secret" {
  count = local.is_aws_transfer_server && length(data.aws_secretsmanager_secrets.transfer_secrets[0].arns) > 0 ? 1 : 0
  arn   = tolist(data.aws_secretsmanager_secrets.transfer_secrets[0].arns)[0]
}

# Get the KMS key from the detected secret
locals {
  detected_secret_kms_key = local.is_aws_transfer_server && length(data.aws_secretsmanager_secret.transfer_secret) > 0 ? data.aws_secretsmanager_secret.transfer_secret[0].kms_key_id : null
}

locals {
  should_scan = false
  logging_role = length(aws_iam_role.connector_logging_role) > 0 ? aws_iam_role.connector_logging_role[0].arn : null
  
  # Check if URL is AWS Transfer Family server
  is_aws_transfer_server = can(regex("server\\.transfer\\.[a-z0-9-]+\\.amazonaws\\.com", var.url))
  
  # Use auto-detected secret for AWS Transfer servers, otherwise use provided secret
  effective_secret_id = local.is_aws_transfer_server && length(data.aws_secretsmanager_secret.transfer_secret) > 0 ? data.aws_secretsmanager_secret.transfer_secret[0].arn : var.user_secret_id
}

#####################################################################################
# Data Sources
#####################################################################################

data "aws_region" "current" {}

# Try to get connector IP information via AWS CLI
data "external" "connector_ips" {
  program = ["bash", "-c", <<-EOF
    # Try to describe the connector and extract any IP information
    connector_info=$(aws transfer describe-connector --connector-id "${aws_transfer_connector.sftp_connector.id}" --region "${data.aws_region.current.name}" 2>/dev/null || echo "{}")
    
    # Extract IP addresses if they exist and format as comma-separated string
    ips=$(echo "$connector_info" | jq -r '.Connector.ServiceManagedEgressIpAddresses // [] | join(",")')
    
    if [ -n "$ips" ] && [ "$ips" != "" ]; then
      echo "{\"ips\": \"$ips\", \"status\": \"found\"}"
    else
      echo "{\"ips\": \"\", \"status\": \"not_available\", \"note\": \"No IP addresses available via API\"}"
    fi
  EOF
  ]
  
  depends_on = [aws_transfer_connector.sftp_connector]
}



# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  count = local.should_scan ? 1 : 0
  
  name = "transfer-connector-lambda-role-${var.connector_name}"

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

  tags = var.tags
}

# IAM policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  count = local.should_scan ? 1 : 0
  
  name = "transfer-connector-lambda-policy-${var.connector_name}"
  role = aws_iam_role.lambda_role[0].id

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
          "transfer:DescribeConnector"
        ]
        Resource = "*"
      }
    ]
  })
}

#####################################################################################
# SFTP Connector
#####################################################################################

resource "aws_transfer_connector" "sftp_connector" {
  access_role = aws_iam_role.connector_role.arn
  url         = var.url

  # SFTP config without trusted_host_keys (optional)
  dynamic "sftp_config" {
    for_each = local.effective_secret_id != null ? [1] : []
    content {
      user_secret_id = local.effective_secret_id
    }
  }

  logging_role = local.logging_role
  security_policy_name = var.security_policy_name

  tags = merge(
    var.tags,
    {
      Name = var.connector_name
    }
  )

}

#####################################################################################
# IAM Role and Policy for the SFTP Connector
#####################################################################################

resource "aws_iam_role" "connector_role" {
  name = "transfer-connector-role-${var.connector_name}"
  
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

  tags = var.tags
}

# This policy is based off the example from the official AWS documentation https://docs.aws.amazon.com/transfer/latest/userguide/create-sftp-connector-procedure.html
resource "aws_iam_policy" "connector_policy" {
  name        = "transfer-connector-policy-${var.connector_name}"
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
        Resource = var.s3_bucket_arn
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
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Sid = "GetConnectorSecretValue",
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = local.effective_secret_id
      },
    ], var.secrets_manager_kms_key_arn != null ? [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt"
      ]
      Resource = local.detected_secret_kms_key != null ? local.detected_secret_kms_key : var.secrets_manager_kms_key_arn
    }] : [], var.kms_key_arn != null ? [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      Resource = var.kms_key_arn
    }] : [])
  })
}

resource "aws_iam_role_policy_attachment" "connector_policy_attachment" {
  role       = aws_iam_role.connector_role.name
  policy_arn = aws_iam_policy.connector_policy.arn
}

#####################################################################################
# CloudWatch Logging Role and Policy (if not provided)
#####################################################################################

resource "aws_iam_role" "connector_logging_role" {
  count = var.logging_role == null ? 1 : 0
  
  name = "transfer-connector-logging-role-${var.connector_name}"
  
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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "connector_logging_policy" {
  count      = var.logging_role == null ? 1 : 0
  role       = aws_iam_role.connector_logging_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSTransferLoggingAccess"
}

#####################################################################################
# AWS Transfer Family SFTP Connector Module
# This module creates an AWS Transfer Family SFTP connector to connect an S3 bucket to an SFTP server
#####################################################################################

resource "aws_transfer_connector" "sftp_connector" {
  access_role = aws_iam_role.connector_role.arn
  url         = var.sftp_server_url

  # AS2 config is only needed for AS2 connectors, not SFTP
  dynamic "as2_config" {
    for_each = var.as2_username != "" && var.as2_password != "" ? [1] : []
    content {
      compression           = var.as2_compression
      encryption_algorithm  = var.as2_encryption_algorithm
      local_profile_id      = var.as2_local_profile_id
      mdn_response          = var.as2_mdn_response
      partner_profile_id    = var.as2_partner_profile_id
      signing_algorithm     = var.as2_signing_algorithm
    }
  }

  # SFTP config is required for SFTP connectors
  sftp_config {
    user_secret_id         = var.user_secret_id
    trusted_host_keys      = var.trusted_host_keys
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

resource "aws_iam_policy" "connector_policy" {
  name        = "transfer-connector-policy-${var.connector_name}"
  description = "Policy for AWS Transfer Family SFTP connector"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.s3_bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.user_secret_id
      }
    ], var.kms_key_arn != null ? [{
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

locals {
  logging_role = var.logging_role != null ? var.logging_role : (
    length(aws_iam_role.connector_logging_role) > 0 ? aws_iam_role.connector_logging_role[0].arn : null
  )
}

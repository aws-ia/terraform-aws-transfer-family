#####################################################################################
# AWS Transfer Family SFTP Connector Module
# This module creates an AWS Transfer Family SFTP connector to connect an S3 bucket to an SFTP server
#####################################################################################

locals {
  # Use provided roles or create new ones
  s3_access_role_arn = var.s3_access_role_arn != null ? var.s3_access_role_arn : aws_iam_role.s3_access_role[0].arn
  logging_role_arn   = var.logging_role_arn != null ? var.logging_role_arn : aws_iam_role.logging_role[0].arn

  # Determine if we need to auto-discover host keys
  should_auto_discover = var.auto_discover_host_keys && length(var.trusted_host_keys) == 0
  
  # Determine if we need KMS policy (use boolean variable instead of computed value)
  create_kms_policy = var.s3_access_role_arn == null && var.enable_kms_encryption

  # Validation: ensure only one authentication method is provided
  auth_validation = (var.sftp_password != null && var.sftp_private_key != null) ? tobool("ERROR: Only one of sftp_password or sftp_private_key should be provided") : true
  auth_required = (var.sftp_password == null && var.sftp_private_key == null) ? tobool("ERROR: Either sftp_password or sftp_private_key must be provided") : true
}

#####################################################################################
# Secrets Manager for SFTP Credentials
#####################################################################################

resource "aws_secretsmanager_secret" "sftp_credentials" {
  name                    = "${var.connector_name}-sftp-credentials"
  description             = "SFTP credentials for Transfer Family connector ${var.connector_name}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 7

  tags = merge(
    var.tags,
    {
      Name      = "${var.connector_name}-sftp-credentials"
      Purpose   = "Transfer Family SFTP Connector"
      Connector = var.connector_name
    }
  )
}

resource "aws_secretsmanager_secret_version" "sftp_credentials" {
  secret_id = aws_secretsmanager_secret.sftp_credentials.id
  secret_string = var.sftp_private_key != null ? jsonencode({
    Username   = var.sftp_username
    PrivateKey = var.sftp_private_key
  }) : jsonencode({
    Username = var.sftp_username
    Password = var.sftp_password
  })
}

#####################################################################################
# S3 Access IAM Role (created if not provided)
#####################################################################################

resource "aws_iam_role" "s3_access_role" {
  count = var.s3_access_role_arn == null ? 1 : 0

  name = "${var.connector_name}-s3-access-role"

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

  tags = merge(
    var.tags,
    {
      Name    = "${var.connector_name}-s3-access-role"
      Purpose = "Transfer Family SFTP Connector S3 Access"
    }
  )
}

resource "aws_iam_policy" "s3_access_policy" {
  count = var.s3_access_role_arn == null ? 1 : 0

  name        = "${var.connector_name}-s3-access-policy"
  description = "S3 access policy for AWS Transfer Family SFTP connector"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
        Resource = aws_secretsmanager_secret.sftp_credentials.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access_policy_attachment" {
  count      = var.s3_access_role_arn == null ? 1 : 0
  role       = aws_iam_role.s3_access_role[0].name
  policy_arn = aws_iam_policy.s3_access_policy[0].arn
}

# Add KMS permissions if KMS key is provided
resource "aws_iam_policy" "kms_access_policy" {
  count = local.create_kms_policy ? 1 : 0

  name        = "${var.connector_name}-kms-access-policy"
  description = "KMS access policy for AWS Transfer Family SFTP connector"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kms_access_policy_attachment" {
  count      = local.create_kms_policy ? 1 : 0
  role       = aws_iam_role.s3_access_role[0].name
  policy_arn = aws_iam_policy.kms_access_policy[0].arn
}

#####################################################################################
# Logging IAM Role (created if not provided)
#####################################################################################

resource "aws_iam_role" "logging_role" {
  count = var.logging_role_arn == null ? 1 : 0

  name = "${var.connector_name}-logging-role"

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

  tags = merge(
    var.tags,
    {
      Name    = "${var.connector_name}-logging-role"
      Purpose = "Transfer Family SFTP Connector Logging"
    }
  )
}

resource "aws_iam_role_policy_attachment" "logging_policy_attachment" {
  count      = var.logging_role_arn == null ? 1 : 0
  role       = aws_iam_role.logging_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSTransferLoggingAccess"
}

#####################################################################################
# SFTP Connector - Auto-Discovery Configuration
#####################################################################################

resource "aws_transfer_connector" "sftp_connector_auto_discovery" {
  count = local.should_auto_discover ? 1 : 0

  access_role = local.s3_access_role_arn
  url         = var.sftp_server_url

  sftp_config {
    user_secret_id = aws_secretsmanager_secret.sftp_credentials.arn
    # No trusted_host_keys initially - will be added via update
  }

  logging_role         = local.logging_role_arn
  security_policy_name = var.security_policy_name

  tags = merge(
    var.tags,
    {
      Name = var.connector_name
    }
  )

  # Ignore changes to trusted_host_keys as they will be managed by the update process
  lifecycle {
    ignore_changes = [sftp_config[0].trusted_host_keys]
  }
}

#####################################################################################
# SFTP Connector - Manual Host Keys Configuration
#####################################################################################

resource "aws_transfer_connector" "sftp_connector_manual" {
  count = !local.should_auto_discover ? 1 : 0

  access_role = local.s3_access_role_arn
  url         = var.sftp_server_url

  sftp_config {
    user_secret_id    = aws_secretsmanager_secret.sftp_credentials.arn
    trusted_host_keys = var.trusted_host_keys
  }

  logging_role         = local.logging_role_arn
  security_policy_name = var.security_policy_name

  tags = merge(
    var.tags,
    {
      Name = var.connector_name
    }
  )
}

# Local value to get the active connector
locals {
  active_connector = local.should_auto_discover ? aws_transfer_connector.sftp_connector_auto_discovery[0] : aws_transfer_connector.sftp_connector_manual[0]
}

#####################################################################################
# Auto-Discovery of Trusted Host Keys (if enabled)
#####################################################################################

# Test connection to discover host keys
resource "terraform_data" "test_connection" {
  count = local.should_auto_discover ? 1 : 0

  triggers_replace = [
    aws_transfer_connector.sftp_connector_auto_discovery[0].id,
    var.sftp_server_url
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Test connection and capture output
      aws transfer test-connection \
        --connector-id ${aws_transfer_connector.sftp_connector_auto_discovery[0].id} \
        --region ${data.aws_region.current.id} \
        --output json > /tmp/test-connection-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.json
      
      # Extract trusted host keys from the SftpConnectionDetails.HostKey field
      TRUSTED_HOST_KEYS=$(cat /tmp/test-connection-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.json | jq -r '.SftpConnectionDetails.HostKey // empty')
      
      if [ ! -z "$TRUSTED_HOST_KEYS" ] && [ "$TRUSTED_HOST_KEYS" != "null" ]; then
        echo "Discovered host keys: $TRUSTED_HOST_KEYS"
        # Store the discovered keys for the update step
        echo "$TRUSTED_HOST_KEYS" > /tmp/discovered-keys-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.txt
      else
        echo "No host keys discovered or connection failed"
        # Check if there was an error in the response
        ERROR_MSG=$(cat /tmp/test-connection-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.json | jq -r '.StatusMessage // empty')
        if [ ! -z "$ERROR_MSG" ]; then
          echo "Connection test error: $ERROR_MSG"
        fi
        touch /tmp/discovered-keys-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.txt
      fi
    EOT
  }

  depends_on = [aws_transfer_connector.sftp_connector_auto_discovery]
}

# Update connector with discovered host keys
resource "terraform_data" "update_connector_with_host_keys" {
  count = local.should_auto_discover ? 1 : 0

  triggers_replace = [
    terraform_data.test_connection[0].id
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Read discovered keys
      if [ -f "/tmp/discovered-keys-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.txt" ]; then
        DISCOVERED_KEYS=$(cat /tmp/discovered-keys-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.txt)
        
        if [ ! -z "$DISCOVERED_KEYS" ] && [ "$DISCOVERED_KEYS" != "null" ]; then
          echo "Updating connector with discovered host keys: $DISCOVERED_KEYS"
          
          # Update the connector with discovered host keys
          aws transfer update-connector \
            --connector-id ${aws_transfer_connector.sftp_connector_auto_discovery[0].id} \
            --region ${data.aws_region.current.id} \
            --sftp-config "UserSecretId=${aws_secretsmanager_secret.sftp_credentials.arn},TrustedHostKeys=$DISCOVERED_KEYS"
        else
          echo "No host keys to update"
        fi
        
        # Clean up temporary files
        rm -f /tmp/test-connection-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.json
        rm -f /tmp/discovered-keys-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.txt
      fi
    EOT
  }

  depends_on = [terraform_data.test_connection]
}

#####################################################################################
# Data Sources
#####################################################################################

data "aws_region" "current" {}

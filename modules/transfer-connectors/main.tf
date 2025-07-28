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
      set -e
      
      echo "Discovering host keys for URL: ${var.sftp_server_url}"
      
      # Wait for the Transfer server to be fully ready
      echo "Waiting 30 seconds for Transfer server to be fully operational..."
      sleep 30
      
      # Extract hostname and port from URL
      URL="${var.sftp_server_url}"
      # Remove sftp:// prefix
      URL_WITHOUT_PROTOCOL=$${URL#sftp://}
      # Extract hostname (everything before the first colon, if any)
      HOSTNAME=$${URL_WITHOUT_PROTOCOL%%:*}
      # Extract port (everything after the first colon, if any)
      if [[ "$${URL_WITHOUT_PROTOCOL}" == *":"* ]]; then
        PORT=$${URL_WITHOUT_PROTOCOL#*:}
        # Remove any path after the port
        PORT=$${PORT%%/*}
      else
        PORT=22
      fi
      
      echo "Using hostname: $${HOSTNAME}, port: $${PORT}"
      
      # Use ssh-keyscan to discover host keys with retry logic
      echo "Running ssh-keyscan with retry logic..."
      
      HOST_KEY=""
      
      # Try 5 times with 10 second intervals
      for attempt in 1 2 3 4 5; do
        echo "Attempt $${attempt}/5: Scanning for host keys..."
        
        # Try to get any SSH host key (rsa, ed25519, ecdsa) - exclude comment lines
        HOST_KEY=$(ssh-keyscan -p $${PORT} $${HOSTNAME} 2>/dev/null | grep -v '^#' | head -n 1)
        
        if [ -z "$${HOST_KEY}" ]; then
          echo "No host key found on attempt $${attempt}, waiting 10 seconds..."
          if [ $${attempt} -lt 5 ]; then
            sleep 10
          fi
        else
          echo "Host key discovered on attempt $${attempt}"
          break
        fi
      done
      
      if [ ! -z "$${HOST_KEY}" ]; then
        echo "Discovered host key: $${HOST_KEY}"
        echo "$${HOST_KEY}" > /tmp/discovered-keys-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.txt
      else
        echo "Failed to discover host key after 5 attempts"
        echo "This might be due to:"
        echo "1. Network connectivity issues"
        echo "2. SFTP server not ready yet"
        echo "3. Firewall blocking SSH connections"
        echo ""
        echo "You can manually provide host keys using the trusted_host_keys variable"
        touch /tmp/discovered-keys-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.txt
        exit 1
      fi
    EOT
  }

  depends_on = [
    aws_transfer_connector.sftp_connector_auto_discovery,
    var.transfer_server_id  # Ensure the transfer server is ready
  ]
}

# Update connector with discovered host keys
resource "terraform_data" "update_connector_with_host_keys" {
  count = local.should_auto_discover ? 1 : 0

  triggers_replace = [
    terraform_data.test_connection[0].id
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      # Read discovered keys
      if [ -f "/tmp/discovered-keys-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.txt" ]; then
        DISCOVERED_KEY=$(cat /tmp/discovered-keys-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.txt)
        
        if [ ! -z "$DISCOVERED_KEY" ] && [ "$DISCOVERED_KEY" != "null" ]; then
          echo "Updating connector with discovered host key: $DISCOVERED_KEY"
          
          # Create JSON for the SFTP config with the discovered host key
          # Note: TrustedHostKeys expects an array of strings
          SFTP_CONFIG=$(jq -n \
            --arg secret_id "${aws_secretsmanager_secret.sftp_credentials.arn}" \
            --arg host_key "$DISCOVERED_KEY" \
            '{
              UserSecretId: $secret_id,
              TrustedHostKeys: [$host_key]
            }')
          
          echo "SFTP Config JSON: $SFTP_CONFIG"
          
          # Update the connector with discovered host keys
          aws transfer update-connector \
            --connector-id ${aws_transfer_connector.sftp_connector_auto_discovery[0].id} \
            --region ${data.aws_region.current.id} \
            --sftp-config "$SFTP_CONFIG"
          
          echo "Connector updated successfully with discovered host key"
        else
          echo "No host keys to update - connection test may have failed"
        fi
        
        # Clean up temporary files
        rm -f /tmp/test-connection-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.json
        rm -f /tmp/discovered-keys-${aws_transfer_connector.sftp_connector_auto_discovery[0].id}.txt
      else
        echo "No discovered keys file found"
      fi
    EOT
  }

  depends_on = [terraform_data.test_connection]
}

#####################################################################################
# Data Sources
#####################################################################################

data "aws_region" "current" {}

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

locals {
  should_scan = length(var.trusted_host_keys) == 0
  effective_host_keys = local.should_scan && length(data.external.ssh_host_key_discovery) > 0 ? (
    data.external.ssh_host_key_discovery[0].result.host_key != "" ? [data.external.ssh_host_key_discovery[0].result.host_key] : []
  ) : var.trusted_host_keys
}

#####################################################################################
# SSH Host Key Discovery via AWS API
#####################################################################################

# Use ssh-keyscan to discover SSH host keys when trusted_host_keys is empty
data "external" "ssh_host_key_discovery" {
  count = local.should_scan ? 1 : 0
  
  program = ["bash", "-c", <<-EOF
    set -e
    
    # Extract hostname and port from URL
    url='${var.url}'
    hostname=$(echo "$url" | sed -E 's|^[^:]+://([^:/]+).*|\1|')
    port=$(echo "$url" | sed -E 's|^[^:]+://[^:]+:([0-9]+).*|\1|')
    
    # Default to port 22 if no port specified or extraction failed
    if ! echo "$port" | grep -qE '^[0-9]+$'; then
        port=22
    fi
    
    echo "Scanning $hostname:$port for SSH host keys..." >&2
    
    # Try multiple key types and be more aggressive about discovery
    for key_type in rsa ecdsa-sha2-nistp256 ecdsa-sha2-nistp384 ecdsa-sha2-nistp521 ed25519; do
        echo "Trying key type: $key_type" >&2
        host_key=$(timeout 30 ssh-keyscan -p "$port" -t "$key_type" "$hostname" 2>/dev/null | head -1 | tr -d '\r\n')
        if [ -n "$host_key" ] && [ "$host_key" != "" ]; then
            echo "Found $key_type host key: $host_key" >&2
            echo "{\"host_key\": \"$host_key\", \"hostname\": \"$hostname\", \"port\": \"$port\", \"key_type\": \"$key_type\"}"
            exit 0
        fi
    done
    
    # Try with different connection methods
    echo "Trying alternative connection methods..." >&2
    host_key=$(timeout 30 ssh-keyscan -4 -p "$port" "$hostname" 2>/dev/null | head -1 | tr -d '\r\n')
    if [ -n "$host_key" ] && [ "$host_key" != "" ]; then
        echo "Found host key via IPv4: $host_key" >&2
        echo "{\"host_key\": \"$host_key\", \"hostname\": \"$hostname\", \"port\": \"$port\"}"
        exit 0
    fi
    
    # If still no key found, return empty to allow manual configuration
    echo "WARNING: No host key could be discovered for $hostname:$port" >&2
    echo "You must manually provide trusted_host_keys for secure connection" >&2
    echo "{\"host_key\": \"\", \"hostname\": \"$hostname\", \"port\": \"$port\", \"error\": \"no_key_found\"}"
  EOF
  ]
}

#####################################################################################
# SFTP Connector
#####################################################################################

resource "aws_transfer_connector" "sftp_connector" {
  access_role = aws_iam_role.connector_role.arn
  url         = var.url


  # SFTP config is required for SFTP connectors
  dynamic "sftp_config" {
    for_each = var.user_secret_id != null && length(local.effective_host_keys) > 0 ? [1] : []
    content {
      user_secret_id    = var.user_secret_id
      trusted_host_keys = local.effective_host_keys
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
        Resource = var.user_secret_id
      },
    ], var.secrets_manager_kms_key_arn != null ? [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt"
      ]
      Resource = var.secrets_manager_kms_key_arn
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

locals {
  logging_role = var.logging_role != null ? var.logging_role : (
    length(aws_iam_role.connector_logging_role) > 0 ? aws_iam_role.connector_logging_role[0].arn : null
  )
}

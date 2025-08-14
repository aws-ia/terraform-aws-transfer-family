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
locals {
  should_scan = false
  logging_role = length(aws_iam_role.connector_logging_role) > 0 ? aws_iam_role.connector_logging_role[0].arn : null
  
  # Use the provided secret ID directly
  effective_secret_id = var.user_secret_id
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
  depends_on = [
    aws_iam_role_policy_attachment.connector_policy_attachment,
    aws_iam_role_policy_attachment.connector_logging_policy
  ]
  
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

# Discover and test connector with host keys
resource "null_resource" "discover_and_test_connector" {
  depends_on = [aws_transfer_connector.sftp_connector]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Step 1: Testing connection to discover host key..."
      
      MAX_RETRIES=3
      RETRY_COUNT=0
      HOST_KEY=""
      
      while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ -z "$HOST_KEY" ]; do
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Attempt $RETRY_COUNT/$MAX_RETRIES: Testing connection..."
        
        DISCOVERY_RESULT=$(aws transfer test-connection \
          --connector-id ${aws_transfer_connector.sftp_connector.id} \
          --region ${data.aws_region.current.id} \
          --output json 2>/dev/null || echo '{}')
        
        echo "DEBUG - Discovery Result: $DISCOVERY_RESULT"
        
        STATUS=$(echo "$DISCOVERY_RESULT" | jq -r '.Status // empty')
        echo "DEBUG - Status: $STATUS"
        
        if [ "$STATUS" = "ERROR" ]; then
          ERROR_MSG=$(echo "$DISCOVERY_RESULT" | jq -r '.StatusMessage // empty')
          echo "Connection test failed: $ERROR_MSG"
          echo "DEBUG - Full error response: $DISCOVERY_RESULT"
          
          if echo "$ERROR_MSG" | grep -q "Cannot access secret manager"; then
            echo "Secret manager not ready, waiting 10 seconds..."
            sleep 10
            continue
          fi
        fi
        
        HOST_KEY=$(echo "$DISCOVERY_RESULT" | jq -r '.SftpConnectionDetails.HostKey // empty')
        echo "DEBUG - Host Key: $HOST_KEY"
        
        if [ -n "$HOST_KEY" ] && [ "$HOST_KEY" != "null" ]; then
          echo "✅ Discovered host key: $HOST_KEY"
          break
        else
          echo "Host key not found, waiting 10 seconds..."
          sleep 10
        fi
      done
      
      if [ -n "$HOST_KEY" ] && [ "$HOST_KEY" != "null" ]; then
        echo "Step 2: Updating connector with discovered host key..."
        UPDATE_RESULT=$(aws transfer update-connector \
          --connector-id ${aws_transfer_connector.sftp_connector.id} \
          --region ${data.aws_region.current.id} \
          --url "${var.url}" \
          --access-role "${aws_iam_role.connector_role.arn}" \
          --logging-role "${local.logging_role}" \
          --sftp-config "UserSecretId=${local.effective_secret_id},TrustedHostKeys=$HOST_KEY" \
          --output json)
        
        echo "DEBUG - Update Result: $UPDATE_RESULT"
        
        echo "Step 3: Testing final connection with trusted host key..."
        FINAL_TEST=$(aws transfer test-connection \
          --connector-id ${aws_transfer_connector.sftp_connector.id} \
          --region ${data.aws_region.current.id} \
          --output json)
        
        echo "DEBUG - Final Test Result: $FINAL_TEST"
        
        FINAL_STATUS=$(echo "$FINAL_TEST" | jq -r '.Status')
        echo "Final connection status: $FINAL_STATUS"
        
        if [ "$FINAL_STATUS" = "OK" ]; then
          echo "🎉 Connector fully configured and tested successfully!"
        else
          echo "❌ Final test failed: $(echo "$FINAL_TEST" | jq -r '.StatusMessage')"
        fi
      else
        echo "❌ Failed to discover host key after $MAX_RETRIES attempts"
        exit 1
      fi
    EOT
  }
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

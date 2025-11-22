# Transfer Family Web App Module

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM Role for Transfer Family Web App (Bearer Role)
resource "aws_iam_role" "transfer_web_app" {
  name = "${var.web_app_name}-bearer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
        Action = [
          "sts:SetContext",
          "sts:AssumeRole"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Transfer Family Web App with S3 Access Grants
resource "aws_iam_role_policy" "transfer_web_app" {
  name = "${var.web_app_name}-access-grants-policy"
  role = aws_iam_role.transfer_web_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetDataAccess",
          "s3:ListCallerAccessGrants"
        ]
        Resource = "arn:aws:s3:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:access-grants/*"
        Condition = {
          StringEquals = {
            "s3:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListAccessGrantsInstances"
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Transfer Family Web App
resource "awscc_transfer_web_app" "main" {
  identity_provider_details = {
    instance_arn = var.identity_center_instance_arn
    role         = aws_iam_role.transfer_web_app.arn
  }

  access_endpoint = var.access_endpoint

  tags = [
    for key, value in merge(
      var.tags,
      {
        Name = var.web_app_name
      }
      ) : {
      key   = key
      value = value
    }
  ]
}

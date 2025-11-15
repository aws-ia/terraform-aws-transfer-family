# SFTP Web App Example
# This example demonstrates a full setup with S3 bucket, SSO users/groups, and access grants

# Random suffix for unique resource names
resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 2
}

resource "random_id" "suffix" {
  byte_length = 4
}

# S3 bucket for file storage using terraform-aws-modules
module "s3_bucket" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v5.0.0"
  bucket                   = lower("${random_pet.name.id}-web-app-${random_id.suffix.hex}")
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning = {
    enabled = true
  }

  tags = var.tags
}

# SNS topic for CloudTrail notifications
resource "aws_sns_topic" "cloudtrail_notifications" {
  name              = "${random_pet.name.id}-cloudtrail-alerts"
  kms_master_key_id = aws_kms_key.cloudtrail.id
}

# SNS topic policy to allow CloudTrail to publish
resource "aws_sns_topic_policy" "cloudtrail_notifications" {
  arn = aws_sns_topic.cloudtrail_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailSNSPolicy"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cloudtrail_notifications.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# KMS key for CloudTrail encryption
resource "aws_kms_key" "cloudtrail" {
  description             = "KMS key for CloudTrail encryption"
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow SNS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "cloudtrail" {
  name          = "alias/${random_pet.name.id}-cloudtrail"
  target_key_id = aws_kms_key.cloudtrail.key_id
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Transfer Web App Module
module "transfer_web_app" {
  source = "../../modules/transfer-web-app"

  # Basic configuration
  iam_role_name                = "${random_pet.name.id}-web-app-role"
  identity_center_instance_arn = var.identity_center_instance_arn

  # S3 bucket configuration
  s3_bucket_arn = module.s3_bucket.s3_bucket_arn

  # Web app customization
  custom_title = var.custom_title
  logo_file    = var.logo_file
  favicon_file = var.favicon_file

  # Identity Store groups and users from variables
  identity_store_groups = var.groups
  identity_store_users = {
    for key, user in var.users : key => {
      display_name = user.display_name
      user_name    = key
      given_name   = user.given_name
      family_name  = user.family_name
      email        = user.email
    }
  }

  # Group memberships from variables
  group_memberships = var.group_memberships

  # Empty access_grants initially to avoid circular dependency
  access_grants = {}

  # CloudTrail configuration for compliance
  cloudtrail_name          = "${random_pet.name.id}-audit-trail"
  cloudtrail_sns_topic_arn = aws_sns_topic.cloudtrail_notifications.arn
  cloudtrail_kms_key_id    = aws_kms_key.cloudtrail.arn

  # CORS configuration
  cors_allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
  cors_allowed_headers = ["*"]

  tags = var.tags
}

# Create a single access grants location for the S3 bucket
resource "aws_s3control_access_grants_location" "bucket" {
  iam_role_arn   = module.transfer_web_app.iam_role_arn
  location_scope = "s3://${module.s3_bucket.s3_bucket_id}/*"
  tags           = var.tags

  depends_on = [module.transfer_web_app]
}

# Create separate access grants for each group
resource "aws_s3control_access_grant" "group_access" {
  for_each                  = var.access_grant_permissions
  access_grants_location_id = aws_s3control_access_grants_location.bucket.access_grants_location_id
  permission                = each.value

  grantee {
    grantee_type       = "DIRECTORY_GROUP"
    grantee_identifier = module.transfer_web_app.identity_store_group_ids[each.key]
  }

  tags = var.tags

  depends_on = [aws_s3control_access_grants_location.bucket]
}

# Assign groups to the Transfer Web App application
resource "aws_ssoadmin_application_assignment" "group_assignments" {
  for_each = var.access_grant_permissions

  application_arn = module.transfer_web_app.application_arn
  principal_id    = module.transfer_web_app.identity_store_group_ids[each.key]
  principal_type  = "GROUP"
}

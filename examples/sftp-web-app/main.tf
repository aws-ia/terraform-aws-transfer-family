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

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_ssoadmin_instances" "identity_center" {}

locals {
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
}

# S3 bucket for file storage
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

# Create Identity Center users
resource "aws_identitystore_user" "users" {
  for_each = var.users

  identity_store_id = local.identity_store_id
  display_name      = each.value.display_name
  user_name         = each.value.user_name

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    value   = each.value.email
    primary = true
  }
}

# Create Identity Center groups
resource "aws_identitystore_group" "groups" {
  for_each = var.groups

  identity_store_id = local.identity_store_id
  display_name      = each.value.group_name
  description       = each.value.description
}

# Create group memberships
resource "aws_identitystore_group_membership" "memberships" {
  for_each = {
    for membership in flatten([
      for group_key, group in var.groups : [
        for user_key in coalesce(group.members, []) : {
          key       = "${group_key}-${user_key}"
          group_key = group_key
          user_key  = user_key
        }
      ]
    ]) : membership.key => membership
  }

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.groups[each.value.group_key].group_id
  member_id         = aws_identitystore_user.users[each.value.user_key].user_id
}

# SNS topic for CloudTrail notifications
resource "aws_sns_topic" "cloudtrail_notifications" {
  name              = "${random_pet.name.id}-cloudtrail-alerts"
  kms_master_key_id = aws_kms_key.cloudtrail.id
}

# SNS topic policy
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

# KMS key for CloudTrail
resource "aws_kms_key" "cloudtrail" {
  description         = "KMS key for CloudTrail encryption"
  enable_key_rotation = true

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

# Transfer Web App Module
module "transfer_web_app" {
  source = "../../modules/transfer-web-app"

  iam_role_name                = "${random_pet.name.id}-web-app-role"
  identity_center_instance_arn = var.identity_center_instance_arn
  custom_title                 = var.custom_title
  logo_file                    = var.logo_file
  favicon_file                 = var.favicon_file

  identity_center_users = [
    for user_key, user in var.users : {
      username = user.user_name
      access_grants = user.access_path != null ? [{
        s3_path    = "${module.s3_bucket.s3_bucket_id}/${user.access_path}"
        permission = coalesce(user.permission, "READWRITE")
      }] : []
    }
  ]

  identity_center_groups = [
    for group_key, group in var.groups : {
      group_name = group.group_name
      access_grants = [{
        s3_path    = "${module.s3_bucket.s3_bucket_id}/${coalesce(group.access_path, "*")}"
        permission = coalesce(group.permission, "READWRITE")
      }]
    }
  ]

  tags = var.tags

  depends_on = [
    aws_identitystore_user.users,
    aws_identitystore_group.groups
  ]
}

# CORS configuration for S3 bucket
resource "aws_s3_bucket_cors_configuration" "web_app" {
  bucket = module.s3_bucket.s3_bucket_id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = [module.transfer_web_app.web_app_endpoint]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# CloudTrail for audit logging
resource "aws_cloudtrail" "web_app_audit" {
  name                          = "${random_pet.name.id}-audit-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true
  sns_topic_name                = aws_sns_topic.cloudtrail_notifications.arn
  kms_key_id                    = aws_kms_key.cloudtrail.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${module.s3_bucket.s3_bucket_arn}/*"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = lower("${random_pet.name.id}-cloudtrail-logs-${random_id.suffix.hex}")
  force_destroy = true
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

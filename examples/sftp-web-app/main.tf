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
  identity_store_id         = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
  access_grants_instance_id = var.access_grants_instance_arn != null ? var.access_grants_instance_arn : aws_s3control_access_grants_instance.instance[0].access_grants_instance_id
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

# S3 Access Grants Instance (create if not provided)
resource "aws_s3control_access_grants_instance" "instance" {
  count = var.access_grants_instance_arn == null ? 1 : 0

  identity_center_arn = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  tags                = var.tags
}

# IAM role for S3 Access Grants Location (to break circular dependency)
data "aws_iam_policy_document" "access_grants_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["access-grants.s3.amazonaws.com"]
    }
    actions = ["sts:AssumeRole", "sts:SetContext"]
  }
}

resource "aws_iam_role" "access_grants_location_role" {
  name               = "${random_pet.name.id}-access-grants-location-role"
  assume_role_policy = data.aws_iam_policy_document.access_grants_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "access_grants_location_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      module.s3_bucket.s3_bucket_arn,
      "${module.s3_bucket.s3_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "access_grants_location_policy" {
  name   = "${random_pet.name.id}-access-grants-location-policy"
  role   = aws_iam_role.access_grants_location_role.id
  policy = data.aws_iam_policy_document.access_grants_location_policy.json
}

# S3 Access Grants Location
resource "aws_s3control_access_grants_location" "location" {
  account_id     = data.aws_caller_identity.current.account_id
  iam_role_arn   = aws_iam_role.access_grants_location_role.arn
  location_scope = "s3://${module.s3_bucket.s3_bucket_id}"
  tags           = var.tags
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
  s3_access_grants_instance_id = local.access_grants_instance_id
  custom_title                 = var.custom_title
  logo_file                    = var.logo_file
  favicon_file                 = var.favicon_file
  cloudtrail_name              = "${random_pet.name.id}-audit-trail"
  cloudtrail_sns_topic_arn     = aws_sns_topic.cloudtrail_notifications.arn
  cloudtrail_kms_key_id        = aws_kms_key.cloudtrail.arn
  s3_bucket_names              = [module.s3_bucket.s3_bucket_id]
  cors_allowed_methods         = ["GET", "PUT", "POST", "DELETE", "HEAD"]
  cors_allowed_headers         = ["*"]

  identity_center_users = [
    for user_key, user in var.users : {
      username = user.user_name
      access_grants = user.access_path != null ? [{
        location_id = aws_s3control_access_grants_location.location.access_grants_location_id
        path        = user.access_path
        permission  = coalesce(user.permission, "READWRITE")
      }] : []
    }
  ]

  identity_center_groups = [
    for group_key, group in var.groups : {
      group_name = group.group_name
      access_grants = [{
        location_id = aws_s3control_access_grants_location.location.access_grants_location_id
        path        = coalesce(group.access_path, "*")
        permission  = coalesce(group.permission, "READWRITE")
      }]
    }
  ]

  tags = var.tags

  depends_on = [
    aws_identitystore_user.users,
    aws_identitystore_group.groups,
    aws_s3control_access_grants_location.location
  ]
}

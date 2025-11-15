# Transfer Web App Module
# This module creates web application resources for AWS Transfer Family

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_ssoadmin_instances" "identity_center" {}

# Identity Store Groups
resource "aws_identitystore_group" "groups" {
  for_each = var.identity_store_groups

  display_name      = each.value.display_name
  description       = each.value.description
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
}

# Identity Store Users
resource "aws_identitystore_user" "users" {
  for_each = var.identity_store_users

  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
  display_name      = each.value.display_name
  user_name         = each.value.user_name

  name {
    given_name  = each.value.given_name
    family_name = each.value.family_name
  }

  emails {
    value = each.value.email
  }
}

# Group Memberships
resource "aws_identitystore_group_membership" "memberships" {
  for_each = {
    for membership in flatten([
      for group_key, user_keys in var.group_memberships : [
        for user_key in user_keys : {
          key       = "${group_key}-${user_key}"
          group_key = group_key
          user_key  = user_key
        }
      ]
    ]) : membership.key => membership
  }

  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
  group_id          = aws_identitystore_group.groups[each.value.group_key].group_id
  member_id         = aws_identitystore_user.users[each.value.user_key].user_id
}

# S3 Access Grants Instance (create if not provided)
resource "aws_s3control_access_grants_instance" "this" {
  count               = var.s3_access_grants_instance_id == null ? 1 : 0
  identity_center_arn = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  tags                = var.tags
}

# Local to determine which instance to use
locals {
  access_grants_instance_id = var.s3_access_grants_instance_id != null ? var.s3_access_grants_instance_id : aws_s3control_access_grants_instance.this[0].id
}

# IAM assume role policy for Transfer service
data "aws_iam_policy_document" "assume_role_transfer" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:SetContext"
    ]
    principals {
      type        = "Service"
      identifiers = ["transfer.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "aws:SourceAccount"
    }
  }
}

# IAM role for Transfer web app
resource "aws_iam_role" "transfer_web_app" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_transfer.json
  tags               = var.tags
}

# IAM policy document for S3 Access Grants
data "aws_iam_policy_document" "transfer_web_app" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetDataAccess",
      "s3:ListCallerAccessGrants",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:access-grants/*"
    ]
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "s3:ResourceAccount"
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ListAccessGrantsInstances"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      values   = [data.aws_caller_identity.current.account_id]
      variable = "s3:ResourceAccount"
    }
  }
}

# IAM role policy attachment
resource "aws_iam_role_policy" "transfer_web_app" {
  policy = data.aws_iam_policy_document.transfer_web_app.json
  role   = aws_iam_role.transfer_web_app.name
}

# Transfer Web App
resource "aws_transfer_web_app" "web_app" {
  identity_provider_details {
    identity_center_config {
      instance_arn = var.identity_center_instance_arn != null ? var.identity_center_instance_arn : tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
      role         = aws_iam_role.transfer_web_app.arn
    }
  }

  web_app_units {
    provisioned = var.provisioned_units
  }

  tags = var.tags
}

# Transfer Web App Customization (separate resource)
resource "aws_transfer_web_app_customization" "web_app" {
  count = var.logo_file != null || var.favicon_file != null || var.custom_title != null ? 1 : 0
  
  web_app_id   = aws_transfer_web_app.web_app.web_app_id
  favicon_file = var.favicon_file != null ? filebase64(var.favicon_file) : null
  logo_file    = var.logo_file != null ? filebase64(var.logo_file) : null
  title        = var.custom_title
}

# CORS configuration for S3 bucket
locals {
  bucket_name = var.s3_bucket_arn != null ? regex("arn:aws:s3:::([^/]+)", var.s3_bucket_arn)[0] : null
  # Combine user-defined origins with the Transfer Family web app endpoint
  cors_origins = var.s3_bucket_arn != null ? concat(
    var.cors_allowed_origins,
    ["https://${aws_transfer_web_app.web_app.access_endpoint}"]
  ) : []
}

resource "aws_s3_bucket_cors_configuration" "web_app_cors" {
  bucket = local.bucket_name

  cors_rule {
    allowed_headers = var.cors_allowed_headers
    allowed_methods = var.cors_allowed_methods
    allowed_origins = local.cors_origins
  }

  depends_on = [aws_transfer_web_app.web_app]
}

# S3 Access Grants Location
resource "aws_s3control_access_grants_location" "web_app" {
  for_each = var.access_grants

  iam_role_arn   = aws_iam_role.transfer_web_app.arn
  location_scope = each.value.location_scope
  tags           = var.tags

  depends_on = [
    aws_transfer_web_app.web_app,
    aws_identitystore_group.groups,
    aws_identitystore_user.users
  ]
}

# S3 Access Grant
resource "aws_s3control_access_grant" "web_app" {
  for_each                  = var.access_grants
  access_grants_location_id = aws_s3control_access_grants_location.web_app[each.key].access_grants_location_id
  permission                = each.value.permission

  dynamic "access_grants_location_configuration" {
    for_each = each.value.s3_sub_prefix != null ? [1] : []
    content {
      s3_sub_prefix = each.value.s3_sub_prefix
    }
  }

  grantee {
    grantee_type       = each.value.grantee_type
    grantee_identifier = each.value.grantee_identifier
  }

  tags = var.tags
}

# CloudTrail S3 bucket (if not provided)
resource "aws_s3_bucket" "cloudtrail" {
  count  = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == null ? 1 : 0
  bucket = "${var.cloudtrail_name}-logs-${random_id.bucket_suffix[0].hex}"
  tags   = var.tags
}

resource "random_id" "bucket_suffix" {
  count       = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == null ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id
  policy = data.aws_iam_policy_document.cloudtrail_s3[0].json
}

data "aws_iam_policy_document" "cloudtrail_s3" {
  count = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == null ? 1 : 0

  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail[0].arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail[0].arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# CloudTrail for audit logging
resource "aws_cloudtrail" "audit_trail" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = var.cloudtrail_name
  s3_bucket_name = var.cloudtrail_s3_bucket_name != null ? var.cloudtrail_s3_bucket_name : aws_s3_bucket.cloudtrail[0].bucket

  # Security configurations
  enable_log_file_validation = true
  is_multi_region_trail      = true
  sns_topic_name             = var.cloudtrail_sns_topic_arn
  kms_key_id                 = var.cloudtrail_kms_key_id

  event_selector {
    read_write_type                  = "All"
    include_management_events        = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${var.s3_bucket_arn}/*"]
    }
  }

  tags = var.tags
}

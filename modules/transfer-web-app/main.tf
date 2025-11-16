# Transfer Web App Module
# This module creates web application resources for AWS Transfer Family

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_ssoadmin_instances" "identity_center" {}



# Local variables
locals {
  identity_store_id            = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
  identity_center_instance_arn = var.identity_center_instance_arn != null ? var.identity_center_instance_arn : tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  access_grants_instance_id    = var.s3_access_grants_instance_id
  application_arn              = aws_transfer_web_app.web_app.identity_provider_details[0].identity_center_config[0].application_arn

  user_grants = flatten([
    for user in var.identity_center_users : [
      for grant in coalesce(user.access_grants, []) : {
        username    = user.username
        location_id = grant.location_id
        path        = grant.path
        permission  = grant.permission
      }
    ]
  ])

  group_grants = flatten([
    for group in var.identity_center_groups : [
      for grant in coalesce(group.access_grants, []) : {
        group_name  = group.group_name
        location_id = grant.location_id
        path        = grant.path
        permission  = grant.permission
      }
    ]
  ])
}

# Data source to lookup Identity Center users
data "aws_identitystore_user" "users" {
  for_each = { for user in var.identity_center_users : user.username => user }

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = each.value.username
    }
  }
}

# Data source to lookup Identity Center groups
data "aws_identitystore_group" "groups" {
  for_each = { for group in var.identity_center_groups : group.group_name => group }

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value.group_name
    }
  }
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
      instance_arn = local.identity_center_instance_arn
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

# Assign users to Transfer Family Web App via Identity Center Application
resource "aws_ssoadmin_application_assignment" "users" {
  for_each = { for user in var.identity_center_users : user.username => user }

  application_arn = local.application_arn
  principal_id    = data.aws_identitystore_user.users[each.key].user_id
  principal_type  = "USER"

  depends_on = [aws_transfer_web_app.web_app]
}

# Assign groups to Transfer Family Web App via Identity Center Application
resource "aws_ssoadmin_application_assignment" "groups" {
  for_each = { for group in var.identity_center_groups : group.group_name => group }

  application_arn = local.application_arn
  principal_id    = data.aws_identitystore_group.groups[each.key].group_id
  principal_type  = "GROUP"

  depends_on = [aws_transfer_web_app.web_app]
}

# Configure CORS for S3 buckets
resource "aws_s3_bucket_cors_configuration" "web_app_cors" {
  count = length(var.s3_bucket_names) > 0 ? length(var.s3_bucket_names) : 0

  bucket = var.s3_bucket_names[count.index]

  cors_rule {
    allowed_headers = var.cors_allowed_headers
    allowed_methods = var.cors_allowed_methods
    allowed_origins = concat(
      var.cors_allowed_origins,
      [aws_transfer_web_app.web_app.access_endpoint]
    )
  }
  depends_on = [aws_transfer_web_app.web_app]
}

# Create S3 Access Grants for users
resource "aws_s3control_access_grant" "user_grants" {
  for_each = {
    for grant in local.user_grants : "${grant.username}-${grant.path}" => grant
  }

  account_id                = data.aws_caller_identity.current.account_id
  access_grants_location_id = each.value.location_id
  permission                = each.value.permission

  grantee {
    grantee_type       = "DIRECTORY_USER"
    grantee_identifier = data.aws_identitystore_user.users[each.value.username].user_id
  }

  access_grants_location_configuration {
    s3_sub_prefix = each.value.path
  }

  tags = var.tags
}

# Create S3 Access Grants for groups
resource "aws_s3control_access_grant" "group_grants" {
  for_each = {
    for grant in local.group_grants : "${grant.group_name}-${grant.path}" => grant
  }

  account_id                = data.aws_caller_identity.current.account_id
  access_grants_location_id = each.value.location_id
  permission                = each.value.permission

  grantee {
    grantee_type       = "DIRECTORY_GROUP"
    grantee_identifier = data.aws_identitystore_group.groups[each.value.group_name].group_id
  }

  access_grants_location_configuration {
    s3_sub_prefix = each.value.path
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

# CloudTrail for audit logging of user authentication and data operations
resource "aws_cloudtrail" "audit_trail" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = var.cloudtrail_name
  s3_bucket_name = var.cloudtrail_s3_bucket_name != null ? var.cloudtrail_s3_bucket_name : aws_s3_bucket.cloudtrail[0].bucket

  # Security configurations
  enable_log_file_validation = true
  is_multi_region_trail      = true
  sns_topic_name             = var.cloudtrail_sns_topic_arn
  kms_key_id                 = var.cloudtrail_kms_key_id

  # Capture management events (includes Identity Center authentication)
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  # Capture S3 data operations for all buckets
  dynamic "event_selector" {
    for_each = length(var.s3_bucket_names) > 0 ? [1] : []
    content {
      read_write_type           = "All"
      include_management_events = false

      dynamic "data_resource" {
        for_each = toset(var.s3_bucket_names)
        content {
          type   = "AWS::S3::Object"
          values = ["arn:aws:s3:::${data_resource.value}/*"]
        }
      }
    }
  }

  tags = var.tags
}

# Transfer Web App Module
# This module creates web application resources for AWS Transfer Family

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_ssoadmin_instances" "identity_center" {}

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
      "arn:${data.aws_partition.current.partition}:s3:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:access-grants/*"
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

  web_app_customization {
    logo_file    = var.logo_file
    favicon_file = var.favicon_file
    title        = var.custom_title
  }
  
  tags = var.tags
}

# CORS configuration for S3 bucket
locals {
  bucket_name = var.s3_bucket_arn != null ? regex("arn:aws:s3:::([^/]+)", var.s3_bucket_arn)[0] : null
}

resource "aws_s3_bucket_cors_configuration" "web_app_cors" {
  count  = var.enable_cors && var.s3_bucket_arn != null ? 1 : 0
  bucket = local.bucket_name

  cors_rule {
    allowed_headers = var.cors_allowed_headers
    allowed_methods = var.cors_allowed_methods
    allowed_origins = var.cors_allowed_origins
  }
}

# S3 Access Grants Location
resource "aws_s3control_access_grants_location" "web_app" {
  for_each = var.create_access_grants ? var.access_grants : {}

  iam_role_arn   = aws_iam_role.transfer_web_app.arn
  location_scope = each.value.location_scope
  tags           = var.tags
}

# S3 Access Grant
resource "aws_s3control_access_grant" "web_app" {
  for_each                  = var.create_access_grants ? var.access_grants : {}
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
  count                         = var.enable_cloudtrail ? 1 : 0
  name                         = var.cloudtrail_name
  s3_bucket_name               = var.cloudtrail_s3_bucket_name != null ? var.cloudtrail_s3_bucket_name : aws_s3_bucket.cloudtrail[0].bucket
  
  # Security configurations
  enable_log_file_validation   = true
  is_multi_region_trail       = true
  sns_topic_name              = var.cloudtrail_sns_topic_arn
  kms_key_id                  = var.cloudtrail_kms_key_id

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }

  tags = var.tags
}

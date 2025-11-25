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
  application_arn              = aws_transfer_web_app.web_app.identity_provider_details[0].identity_center_config[0].application_arn

  user_grants = flatten([
    for user in var.identity_center_users : [
      for grant in coalesce(user.access_grants, []) : {
        username   = user.username
        s3_path    = grant.s3_path
        permission = grant.permission
      }
    ]
  ])

  group_grants = flatten([
    for group in var.identity_center_groups : [
      for grant in coalesce(group.access_grants, []) : {
        group_name = group.group_name
        s3_path    = grant.s3_path
        permission = grant.permission
      }
    ]
  ])

  access_grants_instance_id = coalesce(
    var.s3_access_grants_instance_id,
    try(aws_s3control_access_grants_instance.instance[0].access_grants_instance_id, null)
  )

  all_buckets_location_id = coalesce(
    try([for loc in data.aws_s3control_access_grants_locations.all_buckets[0].locations : 
      loc.access_grants_location_id if loc.location_scope == "s3://"
    ][0], null),
    try(aws_s3control_access_grants_location.all_buckets[0].access_grants_location_id, null)
  )
}

# S3 Access Grants Instance (create if not provided)
resource "aws_s3control_access_grants_instance" "instance" {
  count = var.s3_access_grants_instance_id == null && (length(local.user_grants) > 0 || length(local.group_grants) > 0) ? 1 : 0

  identity_center_arn = local.identity_center_instance_arn
  tags                = var.tags
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

# Check for existing s3:// location
data "aws_s3control_access_grants_locations" "all_buckets" {
  count      = length(local.user_grants) > 0 || length(local.group_grants) > 0 ? 1 : 0
  account_id = data.aws_caller_identity.current.account_id
}

# IAM role for s3:// location
data "aws_iam_policy_document" "access_grants_location_assume_role" {
  count = length(local.user_grants) > 0 || length(local.group_grants) > 0 ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["access-grants.s3.amazonaws.com"]
    }
    actions = ["sts:AssumeRole", "sts:SetContext"]
  }
}

resource "aws_iam_role" "access_grants_location" {
  count = length(local.user_grants) > 0 || length(local.group_grants) > 0 ? 1 : 0

  name               = "${var.iam_role_name}-access-grants-location"
  assume_role_policy = data.aws_iam_policy_document.access_grants_location_assume_role[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "access_grants_location_policy" {
  count = length(local.user_grants) > 0 || length(local.group_grants) > 0 ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role_policy" "access_grants_location" {
  count = length(local.user_grants) > 0 || length(local.group_grants) > 0 ? 1 : 0

  name   = "access-grants-location-policy"
  role   = aws_iam_role.access_grants_location[0].id
  policy = data.aws_iam_policy_document.access_grants_location_policy[0].json
}



# Create s3:// location if it doesn't exist
resource "aws_s3control_access_grants_location" "all_buckets" {
  count = local.all_buckets_location_id == null && (length(local.user_grants) > 0 || length(local.group_grants) > 0) ? 1 : 0

  account_id     = data.aws_caller_identity.current.account_id
  iam_role_arn   = aws_iam_role.access_grants_location[0].arn
  location_scope = "s3://"
  tags           = var.tags

  depends_on = [aws_s3control_access_grants_instance.instance]
}

# Create S3 Access Grants for users
resource "aws_s3control_access_grant" "user_grants" {
  for_each = {
    for grant in local.user_grants : "${grant.username}-${grant.s3_path}" => grant
  }

  account_id                = data.aws_caller_identity.current.account_id
  access_grants_location_id = local.all_buckets_location_id
  permission                = each.value.permission

  grantee {
    grantee_type       = "DIRECTORY_USER"
    grantee_identifier = data.aws_identitystore_user.users[each.value.username].user_id
  }

  access_grants_location_configuration {
    s3_sub_prefix = each.value.s3_path
  }

  tags = var.tags
}

# Create S3 Access Grants for groups
resource "aws_s3control_access_grant" "group_grants" {
  for_each = {
    for grant in local.group_grants : "${grant.group_name}-${grant.s3_path}" => grant
  }

  account_id                = data.aws_caller_identity.current.account_id
  access_grants_location_id = local.all_buckets_location_id
  permission                = each.value.permission

  grantee {
    grantee_type       = "DIRECTORY_GROUP"
    grantee_identifier = data.aws_identitystore_group.groups[each.value.group_name].group_id
  }

  access_grants_location_configuration {
    s3_sub_prefix = each.value.s3_path
  }

  tags = var.tags
}

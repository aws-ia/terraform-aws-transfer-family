# Transfer Family Web App Users and Groups Submodule

# Data source to automatically get Identity Store ID from Identity Center
data "aws_ssoadmin_instances" "main" {}

locals {
  # Automatically derive identity_store_id from Identity Center instance
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
}

# Data source to lookup Identity Center users
data "aws_identitystore_user" "users" {
  for_each = { for user in var.users : user.username => user }

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
  for_each = { for group in var.groups : group.group_name => group }

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value.group_name
    }
  }
}

# Get the Transfer Family Web App details including Application ARN
data "awscc_transfer_web_app" "main" {
  id = var.web_app_arn
}

# Get the SSO instance to retrieve instance ARN
data "aws_ssoadmin_instances" "sso" {}

locals {
  sso_instance_arn = tolist(data.aws_ssoadmin_instances.sso.arns)[0]
  application_arn  = data.awscc_transfer_web_app.main.identity_provider_details.application_arn
}

# Assign users to Transfer Family Web App via Identity Center Application
resource "aws_ssoadmin_application_assignment" "users" {
  for_each = { for user in var.users : user.username => user }

  application_arn = local.application_arn
  principal_id    = data.aws_identitystore_user.users[each.key].user_id
  principal_type  = "USER"
}

# Assign groups to Transfer Family Web App via Identity Center Application
resource "aws_ssoadmin_application_assignment" "groups" {
  for_each = { for group in var.groups : group.group_name => group }

  application_arn = local.application_arn
  principal_id    = data.aws_identitystore_group.groups[each.key].group_id
  principal_type  = "GROUP"
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

# Local variables to flatten access grants
locals {
  user_grants = flatten([
    for user in var.users : [
      for grant in coalesce(user.access_grants, []) : {
        username    = user.username
        location_id = grant.location_id
        path        = grant.path
        permission  = grant.permission
      }
    ]
  ])

  group_grants = flatten([
    for group in var.groups : [
      for grant in coalesce(group.access_grants, []) : {
        group_name  = group.group_name
        location_id = grant.location_id
        path        = grant.path
        permission  = grant.permission
      }
    ]
  ])
}

# Data sources
data "aws_caller_identity" "current" {}

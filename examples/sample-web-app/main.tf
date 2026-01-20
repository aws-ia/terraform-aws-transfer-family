#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

#####################################################################################
# Checks
#####################################################################################

check "identity_center_configuration" {
  assert {
    condition     = (var.identity_center_instance_arn != null && var.identity_store_id != null) || var.create_identity_center_instance == true
    error_message = "Either create_identity_center_instance must be true, or both identity_center_instance_arn and identity_store_id must be provided."
  }
}

check "imported_users_access_grants_permissions" {
  assert {
    condition = alltrue([
      for user_key, user in local.imported_users : alltrue([
        for grant in coalesce(user.access_grants, []) : contains(["READ", "WRITE", "READWRITE"], grant.permission)
      ])
    ])
    error_message = "All access_grants[].permission values in local.imported_users must be READ, WRITE, or READWRITE."
  }
}

check "imported_groups_access_grants_permissions" {
  assert {
    condition = alltrue([
      for group_key, group in local.imported_groups : alltrue([
        for grant in coalesce(group.access_grants, []) : contains(["READ", "WRITE", "READWRITE"], grant.permission)
      ])
    ])
    error_message = "All access_grants[].permission values in local.imported_groups must be READ, WRITE, or READWRITE."
  }
}

#####################################################################################
# Defaults and Locals
#####################################################################################
resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 2
}

resource "random_id" "suffix" {
  byte_length = 4
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  identity_store_id            = var.create_identity_center_instance ? awscc_sso_instance.identity_center[0].identity_store_id : var.identity_store_id
  identity_center_instance_arn = var.create_identity_center_instance ? awscc_sso_instance.identity_center[0].instance_arn : var.identity_center_instance_arn

  # Create normalized user and group structures for the module
  # This handles both var.test_users (with full user details) and local.imported_users (with just username/grants)
  normalized_users = var.create_test_users_and_groups ? {
    # Extract from var.test_users (full user objects)
    for user_key, user in var.test_users : user_key => {
      user_name     = user.user_name
      access_grants = try(user.access_grants, [])
    }
    } : {
    # Extract from local.imported_users (simple user objects)
    for user_key, user in local.imported_users : user_key => {
      user_name     = user.user_name
      access_grants = try(user.access_grants, [])
    }
  }

  normalized_groups = var.create_test_users_and_groups ? {
    # Extract from var.test_groups (full group objects) 
    for group_key, group in var.test_groups : group_key => {
      group_name    = group.group_name
      access_grants = try(group.access_grants, [])
    }
    } : {
    # Extract from local.imported_groups (simple group objects)
    for group_key, group in local.imported_groups : group_key => {
      group_name    = group.group_name
      access_grants = try(group.access_grants, [])
    }
  }
}

#####################################################################################
# Create Amazon S3 destination bucket for file storage
#####################################################################################
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
    enabled = false # Turn on versioning if needed
  }

  tags = var.tags
}

#####################################################################################
# Transfer Web App module 
#####################################################################################
module "transfer_web_app" {
  source = "../../modules/transfer-web-app"

  iam_role_name                = "${random_pet.name.id}-web-app-role"
  identity_center_instance_arn = local.identity_center_instance_arn
  identity_store_id            = local.identity_store_id
  custom_title                 = var.custom_title
  logo_file                    = var.logo_file
  favicon_file                 = var.favicon_file

  identity_center_users = [
    for user_key, user in local.normalized_users : {
      username = user.user_name
      access_grants = user.access_grants != null ? [
        for grant in user.access_grants : {
          s3_path    = "${module.s3_bucket.s3_bucket_id}${grant.s3_path}"
          permission = grant.permission
        }
      ] : []
    }
  ]

  identity_center_groups = [
    for group_key, group in local.normalized_groups : {
      group_name = group.group_name
      access_grants = [
        for grant in coalesce(group.access_grants, []) : {
          s3_path    = "${module.s3_bucket.s3_bucket_id}${grant.s3_path}"
          permission = grant.permission
        }
      ]
    }
  ]

  tags = var.tags

  depends_on = [
    module.s3_bucket,
    aws_identitystore_user.users,
    aws_identitystore_group.groups
  ]
}

#####################################################################################
# CORS configuration for S3 destination bucket
#####################################################################################
resource "aws_s3_bucket_cors_configuration" "web_app" {
  bucket = module.s3_bucket.s3_bucket_id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = [module.transfer_web_app.web_app_endpoint]
    expose_headers  = ["ETag"]
  }
}

#####################################################################################
# Create IAM Identity Center instance (optional)
#####################################################################################
resource "awscc_sso_instance" "identity_center" {
  count = var.create_identity_center_instance ? 1 : 0
  name  = "${random_id.suffix.hex}-identity-center"
}

#####################################################################################
# Create AWS IAM Identity Center users, groups, and membership (optional)
#####################################################################################
resource "aws_identitystore_user" "users" {
  for_each = var.create_test_users_and_groups ? var.test_users : {}

  identity_store_id = local.identity_store_id
  display_name      = each.value.display_name
  user_name         = each.value.user_name

  name {
    given_name  = each.value.first_name
    family_name = each.value.last_name
  }

  emails {
    value   = each.value.email
    primary = true
  }
}

resource "aws_identitystore_group" "groups" {
  for_each = var.create_test_users_and_groups ? var.test_groups : {}

  identity_store_id = local.identity_store_id
  display_name      = each.value.group_name
  description       = each.value.description
}

resource "aws_identitystore_group_membership" "memberships" {
  for_each = var.create_test_users_and_groups ? {
    for membership in flatten([
      for group_key, group in var.test_groups : [
        for user_key in coalesce(group.members, []) : {
          key       = "${group_key}-${user_key}"
          group_key = group_key
          user_key  = user_key
        }
      ]
    ]) : membership.key => membership
  } : {}

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.groups[each.value.group_key].group_id
  member_id         = aws_identitystore_user.users[each.value.user_key].user_id
}

#####################################################################################
# Create SNS resources for CloudTrail notifications
#####################################################################################
resource "aws_sns_topic" "cloudtrail_notifications" {
  name              = "${random_pet.name.id}-cloudtrail-alerts"
  kms_master_key_id = aws_kms_key.cloudtrail.id
}

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

#####################################################################################
# Create CloudTrail and related resources (AWS KMS Key, Logging Bucket, etc)
#####################################################################################

resource "aws_kms_key" "cloudtrail" {
  description         = "KMS key for CloudTrail encryption"
  enable_key_rotation = true
}

resource "aws_kms_key_policy" "cloudtrail" {
  key_id = aws_kms_key.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = aws_kms_key.cloudtrail.arn
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
        Resource = aws_kms_key.cloudtrail.arn
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
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
        Resource = aws_kms_key.cloudtrail.arn
      },
      {
        Sid    = "Allow CloudTrail to publish to SNS"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = aws_kms_key.cloudtrail.arn
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.cloudtrail.arn
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/cloudtrail/${random_pet.name.id}"
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "cloudtrail" {
  name          = "alias/${random_pet.name.id}-cloudtrail"
  target_key_id = aws_kms_key.cloudtrail.key_id
}

resource "aws_cloudtrail" "web_app_audit" {
  name                          = "${random_pet.name.id}-audit-trail"
  s3_bucket_name                = module.s3_bucket_cloudtrail_logs.s3_bucket_id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true
  sns_topic_name                = aws_sns_topic.cloudtrail_notifications.arn
  kms_key_id                    = aws_kms_key.cloudtrail.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch_logs.arn

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

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${random_pet.name.id}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.cloudtrail.arn
}

resource "aws_iam_role" "cloudtrail_cloudwatch_logs" {
  name = "${random_pet.name.id}-cloudtrail-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch_logs" {
  name = "cloudtrail-cloudwatch-logs-policy"
  role = aws_iam_role.cloudtrail_cloudwatch_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

module "s3_bucket_cloudtrail_logs" {
  source                   = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v5.0.0"
  bucket                   = lower("${random_pet.name.id}-web-app-cloudtrail-logs-${random_id.suffix.hex}")
  force_destroy            = true # WARNING: Not suitable for production - deletes all bucket contents on destroy
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.cloudtrail.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning = {
    enabled = false # Turn on versioning if needed
  }

  tags = var.tags
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = module.s3_bucket_cloudtrail_logs.s3_bucket_id

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
        Resource = module.s3_bucket_cloudtrail_logs.s3_bucket_arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${module.s3_bucket_cloudtrail_logs.s3_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
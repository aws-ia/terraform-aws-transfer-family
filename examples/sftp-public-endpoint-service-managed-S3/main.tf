#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

######################################
# Defaults and Locals
######################################

resource "random_pet" "name" {
  prefix = "aws-ia"
  length = 1
}

###################################################################
# Create S3 bucket for Transfer Server (Optional if already exists)
###################################################################
module "s3_bucket" {
  source                   = "terraform-aws-modules/s3-bucket/aws"
  version                  = ">=3.5.0"
  bucket                   = lower("${random_pet.name.id}-${module.transfer_server.server_id}-s3-sftp")
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.sse_encryption.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  logging = {
    target_bucket = module.log_delivery_bucket.s3_bucket_id
    target_prefix = "log/"
  }

  depends_on = [
    module.log_delivery_bucket
  ]

  versioning = {
    enabled = true # Turn off versioning to save costs if this is not necessary for your use-case
  }
}

#######################################################################
# Create S3 bucket for Server Access Logs (Optional if already exists)
#######################################################################

#TFSEC Bucket logging for services access logs supressed. 
#tfsec:ignore:aws-s3-enable-bucket-logging
module "log_delivery_bucket" {
  source                   = "terraform-aws-modules/s3-bucket/aws"
  version                  = ">=3.5.0"
  bucket                   = lower("${random_pet.name.id}-${module.transfer_server.server_id}-s3-sftp-logs")
  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.sse_encryption.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  versioning = {
    enabled = true
  }
}

resource "aws_kms_key" "sse_encryption" {
  description             = "KMS key for encrypting S3 buckets and EBS volumes"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# # Create IAM role for SFTP users
# resource "aws_iam_role" "sftp_user_roles" {
#   for_each = { for user in local.users : user.username => user }

#   name = "transfer-user-${each.value.username}"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "transfer.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# # Update the IAM role policy for SFTP users
# resource "aws_iam_role_policy" "sftp_user_policies" {
#   for_each = { for user in local.users : user.username => user }

#   name = "sftp-user-policy-${each.value.username}"
#   role = aws_iam_role.sftp_user_roles[each.key].id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AllowListingOfUserFolder"
#         Effect = "Allow"
#         Action = [
#           "s3:ListBucket",
#           "s3:GetBucketLocation"
#         ]
#         Resource = [
#           module.s3_bucket.s3_bucket_arn
#         ]
#         # Condition = {
#         #   StringLike = {
#         #     "s3:prefix" = ["${each.value.home_dir}/*", "${each.value.home_dir}", ""]
#         #   }
#         # }
#       },
#       {
#         Sid    = "HomeDirObjectAccess"
#         Effect = "Allow"
#         Action = [
#           "s3:PutObject",
#           "s3:GetObject",
#           "s3:DeleteObject",
#           "s3:DeleteObjectVersion",
#           "s3:GetObjectVersion",
#           "s3:GetObjectACL",
#           "s3:PutObjectACL"
#         ]
#         Resource = [
#           "${module.s3_bucket.s3_bucket_arn}${each.value.home_dir}/*",
#           "${module.s3_bucket.s3_bucket_arn}${each.value.home_dir}"
#         ]
#       },
#       {
#         Sid    = "AllowKMSAccess"
#         Effect = "Allow"
#         Action = [
#           "kms:Decrypt",
#           "kms:GenerateDataKey"
#         ]
#         Resource = [
#           aws_kms_key.sse_encryption.arn
#         ]
#       }
#     ]
#   })
# }

module "transfer_server" {
  source = "../.."
  
  transfer_server_base = {
    domain        = "S3"
    protocols     = ["SFTP"]
    endpoint_type = "PUBLIC"
    server_name   = "transfer_server"
  }

  identity_provider = {
    type = "SERVICE_MANAGED"
  }
}

# Read users from CSV
locals {
  users = csvdecode(file(var.users_file))
}

module "sftp_users" {
  source = "../../modules/transfer-user"
  users  = local.users

  server_id = module.transfer_server.server_id

  s3_bucket_name = module.s3_bucket.s3_bucket_id
  s3_bucket_arn  = module.s3_bucket.s3_bucket_arn
}

# module "sftp_keys" {
#   source = "../../modules/sftp-keys"
#   users  = local.users
# }

# # Create SFTP users
# resource "aws_transfer_user" "sftp_users" {
#   for_each = { for user in local.users : user.username => user }

#   server_id = module.transfer_server.server_id
#   user_name = each.value.username
#   role      = aws_iam_role.sftp_user_roles[each.key].arn

#   home_directory_type = "LOGICAL"
#   home_directory_mappings {
#     entry  = "/"
#     target = "/${module.s3_bucket.s3_bucket_id}${each.value.home_dir}"
#   }
# }

# # Create SSH keys for users
# resource "aws_transfer_ssh_key" "user_ssh_keys" {
#   for_each = { for user in local.users : user.username => user }

#   server_id = module.transfer_server.server_id
#   user_name = each.value.username
#     # body      = tls_private_key.sftp_keys[each.key].public_key_openssh
#   body      = module.sftp_keys.public_keys[each.key]

#   depends_on = [aws_transfer_user.sftp_users]
# }